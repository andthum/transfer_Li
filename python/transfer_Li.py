#!/usr/bin/env python3


# MIT License


r"""
Transfer lithium ions from the negative electrode to the positive
electrode.

    1. Identify all "transferable" lithium ions.
    2. Identify the best suitable insertion point for lithium ions at
       the positive electrode.
    3. Transfer each "transferable" lithium ion from the negative
       electrode to the insertion point at the positive electrode.  For
       each transferred lithium ion, create a new .gro file where the
       lithium ion has been transferred and save it to a new directory.
       The created .gro files follow the pattern
       :file:`<settings>_out_<system>_Li<resid>_transferred.gro`.  The
       directory names follow the pattern :file:`Li<resid>_transferred`.

Options
-------
Type :file:`python3 <script_name> -h` in a terminal to get a list of
all options.

Notes
-----
About the identification of "transferable" lithium ions:

All lithium ions that are directly attached to the negative electrode
are considered to be "transferable".  A lithium ion is considered to be
in direct contact with the negative electrode if it is located in the
first bin at the negative electrode surface.

About the identification of the *best suitable* insertion point:

    1. All hexagon centers of the graphene lattice of the positive
       electrode surface are considered to be *possible* positions for
       lithium-ion insertion.
    2. The *possible* insertion points are translated along the normal
       of the electrode surface such that the distance to the nearest
       electrode atom is equal to the Li-C Lennard-Jones equilibrium
       distance :math:`r_{eq} = 2^\frac{1}{6} \sigma_{Li,C}` with
       :math`\sigma_{Li,C} = \sqrt{\sigma_{Li} \sigma_C}` (Good-Hope
       combining rule [1]_ as used for the OPLS-AA force filed [2]_).
    3. The *possible* insertion points with the fewest neighbor atoms
       within :math:`r_{max} = r_{eq} + \sigma_{Li}` and no atoms within
       :math:`r_{min} = \sigma_{Li}` are considered to be *suitable*
       insertion points.
    4. The *best suitable* insertion point is the point with the
       furthest nearest-neighbor atom.

References
----------
.. [1] R. J. Good, C. J. Hope,
    `New Combining Rule for Intermolecular Distances in Intermolecular
    Potential Functions <https://doi.org/10.1063/1.1674022>`_,
    The Journal of Chemical Physics,
    1970 53, 540-543.
.. [2] W. L. Jorgensen, D. S. Maxwell, J. Tirado-Rives,
    `Development and Testing of the OPLS All-Atom Force Field on
    Conformational Energetics and Properties of Organic Liquids
    <https://doi.org/10.1021/ja9621760>`_,
    Journal of the American Chemical Society,
    1996, 118, 45, 11225-11236.
"""


# Standard libraries
import argparse
import os
import sys
from datetime import datetime

# Third-party libraries
import MDAnalysis as mda
import MDAnalysis.lib.distances as mdadist
import mdtools as mdt
import numpy as np


__author__ = "Andreas Thum"


def check_hex_lattice(verts, r0, box, flatside="x", tol=1e-3):
    r"""
    Check if a given hexagonal lattice is suited for the analysis done
    in this script.

    The hexagonal lattice must

        * Lie flat in xy plane.
        * Continue properly across periodic boundaries.

    Parameters
    ----------
    verts : numpy.ndarray
        Array of shape ``(n, 3)`` containing the positions of all ``n``
        vertices of the hexagonal lattice.
    r0 : scalar
        Side length of the hexagons.  Note that the side length of the
        hexagons is related to the lattice constant `a` via
        :math:`a = 2 r_0 \sin{(60°)} = r_0 \sqrt{3}`.
    box : array_like
        The unit cell dimensions of the system, which can be orthogonal
        or triclinic and must be provided in the same format as returned
        by :attr:`MDAnalysis.coordinates.base.Timestep.dimensions`:
        ``[lx, ly, lz, alpha, beta, gamma]``.
    flatside : {'x', 'y'}, optional
        Specify whether the edges of the hexagons align with the x or
        the y axis of the simulation box.
    tol : scalar, optional
        Two floating point numbers are regarded as equal if they deviate
        by less than the tolerance given here.

    Raises
    ------
    ValueError
        If the hexagonal lattice defined by `verts` does not meet the
        above listed requirements.
    """
    verts = mdadist.apply_PBC(verts, box=box)
    if not np.allclose(verts[:, 2], verts[0, 2], rtol=0, atol=tol):
        raise ValueError("The hexagonal lattice must lie flat in xy plane")
    direction = ("x", "y")
    if flatside == "x":
        ix0, ix1 = 0, 1
    elif flatside == "y":
        ix0, ix1 = 1, 0
    else:
        raise ValueError(
            "flatside must be either 'x' or 'y', but you gave"
            " {}".format(flatside)
        )
    if not np.isclose(box[ix0] % (r0 * 3), 0, rtol=0, atol=tol):
        raise ValueError(
            "The hexagonal lattice does not continue properly across periodic"
            "boundaries in {} direction".format(direction[ix0])
        )
    if not np.isclose(box[ix1] % (r0 * np.sqrt(3)), 0, rtol=0, atol=tol):
        raise ValueError(
            "The hexagonal lattice does not continue properly across periodic"
            " boundaries in {} direction".format(direction[ix1])
        )


def hex_verts2faces(verts, r0, box, flatside="x", tol=1e-3):
    r"""
    Calculate the positions of the faces of a hexagonal lattice from the
    positions of the vertices.

    Parameters
    ----------
    verts : numpy.ndarray
        Array of shape ``(n, 3)`` containing the positions of all ``n``
        vertices of the hexagonal lattice.
    r0 : scalar, optional
        Side length of the hexagons.  Note that the side length of the
        hexagons is related to the lattice constant `a` via
        :math:`a = 2 r_0 \sin{(60°)} = r_0 \sqrt{3}`.
    box : array_like, optional
        The unit cell dimensions of the system, which can be orthogonal
        or triclinic and must be provided in the same format as returned
        by :attr:`MDAnalysis.coordinates.base.Timestep.dimensions`:
        ``[lx, ly, lz, alpha, beta, gamma]``.
    flatside : {'x', 'y'}, optional
        Specify whether the edges of the hexagons align with the x or
        the y axis of the simulation box.
    tol : scalar, optional
        Two floating point numbers are regarded as equal if they deviate
        by less than the tolerance given here.

    Returns
    -------
    faces : numpy.ndarray
        Array of shape ``(n/2, 3)`` containing the positions of the
        faces of the hexagonal lattice.  All positions lie within the
        primary unit cell given by `box`.  The faces are sorted by the x
        position as primary sort order, the y position as secondary sort
        order and the z position as tertiary sort order.

    Notes
    -----
    The lattice must lie flat in xy plane and continue properly across
    periodic boundaries.
    """
    check_hex_lattice(verts=verts, r0=r0, box=box, flatside=flatside, tol=tol)
    verts = mdadist.apply_PBC(verts, box=box)
    faces = np.copy(verts)
    if flatside == "x":
        faces[:, 0] += r0
    elif flatside == "y":
        faces[:, 1] += r0
    else:
        raise ValueError(
            "flatside must be either x or y, but you gave"
            " {}".format(flatside)
        )
    faces = mdadist.apply_PBC(faces, box=box)
    precision = int(np.ceil(-np.log10(tol)))
    np.round(faces, precision, out=faces)
    np.round(verts, precision, out=verts)
    if flatside == "x":
        valid = np.isin(faces[:, 0], verts[:, 0], invert=True)
    elif flatside == "y":
        valid = np.isin(faces[:, 1], verts[:, 1], invert=True)
    faces = faces[valid]
    if 2 * len(faces) != len(verts):
        raise ValueError(
            "The number of hexagon faces ({}) is not half the number of"
            " vertices ({}).  This should not have"
            " happened".format(len(faces), len(verts))
        )
    ix_sort = np.lexsort(faces[:, ::-1].T)
    return faces[ix_sort]


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=(
            "Transfer lithium ions from the negative electrode to the positive"
            " electrode."
        )
    )
    parser.add_argument(
        "--system",
        type=str,
        required=True,
        help="Name of the simulated system, e.g. lintf2_g1_20-1_gra_q1_sc80.",
    )
    parser.add_argument(
        "--settings",
        type=str,
        required=False,
        default="pr_nvt423_nh",
        help=(
            "String describing the used simulation settings.  Default:"
            " %(default)s."
        ),
    )
    parser.add_argument(
        "--t0",
        type=int,
        required=True,
        help=(
            "Starting time in ns, i.e. simulation time from which the snapshot"
            " was taken that is used as starting structure."
        ),
    )
    args = parser.parse_args()

    # Input and output file names.
    strfile = (
        args.settings + "_out_" + args.system + "_" + str(args.t0) + "ns.gro"
    )
    topfile = args.settings + "_" + args.system + ".tpr"
    binfile = (
        args.settings + "_" + args.system + "_density-z_number_Li_binsA.txt.gz"
    )
    outfile = args.settings + "_" + args.system + "_transfer_Li.txt.gz"

    # Get lower bin edge of the first bin at the negative electrode.
    cols = (0, 5)
    bins, etrd_dist = np.loadtxt(binfile, usecols=cols, unpack=True)
    z_layer_min = bins[etrd_dist > 0][-1]

    # MDAnalysis atom selection strings.
    # Lithium ions attached to the negative electrode.
    sel_str = "type Li and prop z > {}".format(z_layer_min)
    # All electrolyte atoms.
    elyt_str = "not resname gra*"
    # Atoms defining the positive electrode surface.  Electrodes are
    # modeled by hexagonal graphene lattices.
    surf_str = "type AB1"

    # Properties of the hexagonal graphene lattice.
    # Side length of the hexagons in Angstrom (C-C bond length).
    r0 = 1.42
    # The axis which is parallel to the edges of the hexagons.
    flatside = "x"

    # Lennard-Jones force field parameters.
    # Lennard-Jones size of lithium ions in Angstrom.
    sigma_Li = 2.12645
    # Lennard-Jones size of graphene carbon atoms in Angstrom.
    sigma_C = 3.55000
    # Good-Hope combining rule (used in the OPLS-AA force field).
    sigma_Li_C = np.sqrt(sigma_Li * sigma_C)
    # Li-C Lennard-Jones equilibrium distance.
    r_eq = (2) ** (1 / 6) * sigma_Li_C

    # Create MDAnalysis AtomGroups.
    u = mda.Universe(topfile, strfile)
    sel = u.select_atoms(sel_str)
    surf = u.select_atoms(surf_str)

    # Get positions of possible insertion points.
    hex_centers = hex_verts2faces(
        verts=surf.positions, r0=r0, box=surf.dimensions, flatside=flatside
    )
    # Distance to the lattice surface that is required to keep a
    # distance of `r_eq`` to the next graphene-C when the lithium ion is
    # placed above a hexagon center.
    z_shift = np.sqrt(r_eq**2 - r0**2)
    # Shift hexagon centers to get the coordinates of all possible
    # insertion points.
    hex_centers[:, 2] += z_shift
    # z-position of all hexagon centers, i.e. all possible insertion
    # points.
    z_pos = hex_centers[0][2]

    # Find all atoms within a given cutoff of the possible insertion
    # points.
    # Cutoff within which to search for neighbor atoms.
    r_cut = r_eq + sigma_Li
    zmin = z_pos - r_cut
    zmax = z_pos + r_cut
    # All potentially relevant electrolyte atoms.
    elyt_str += " and prop z >= {} and prop z <= {}".format(zmin, zmax)
    elyt = u.select_atoms(elyt_str)
    dists = mdadist.distance_array(
        hex_centers, elyt.positions, box=elyt.dimensions
    )
    cm = dists <= r_cut  # Contact matrix.
    if not np.any(cm):
        raise ValueError(
            "Couldn't find neighbor atoms for any hexagon center.  You might"
            " want to increase r_cut ({})".format(r_cut)
        )

    # Find the best hexagon center(s) for lithium-ion insertion.
    # Contacts that are too close.
    cm_too_close = dists <= sigma_Li
    # Boolean mask that is True for hexagon centers with too close
    # neighbors.
    too_close = np.any(cm_too_close, axis=1)
    if np.all(too_close):
        raise ValueError(
            "Couldn't find a suitable hexagon center.  All hexagon centers"
            " have too close neighbor atoms.  You might want to decrease"
            " r_min ({})".format(sigma_Li)
        )
    # Number of neighbor atoms for each hexagon center.
    n_neighbors = np.sum(cm, axis=1)
    # Indices of all hexagon centers with the fewest neighbors.
    hex_ixs = np.flatnonzero(n_neighbors == np.min(n_neighbors[~too_close]))
    # Indices of all hexagon centers with too close neighbors.
    hex_ixs_too_close = np.flatnonzero(too_close)
    # Indices of all suitable hexagon centers.
    hex_ixs = np.setdiff1d(hex_ixs, hex_ixs_too_close, assume_unique=True)
    if len(hex_ixs) == 0:
        raise ValueError("Couldn't find a suitable hexagon center")
    min_dists = np.full(hex_ixs.shape, np.nan, dtype=dists.dtype)
    for i, hex_ix in enumerate(hex_ixs):
        # Distance of the nearest neighbor for each suitable hexagon
        # center.
        min_dists[i] = np.min(dists[hex_ix][cm[hex_ix]])
    # Hexagon center with the furthest nearest-neighbor atom.
    hex_ix_best = hex_ixs[np.argmax(min_dists)]
    # Best position for lithium-ion insertion.
    insertion_point = hex_centers[hex_ix_best]

    # Create output
    script_name = str(os.path.basename(sys.argv[0]))
    mdt.fh.backup(outfile)
    with mdt.fh.xopen(outfile, "w") as out:
        out.write(
            "# Created by {} on {}\n".format(
                script_name, datetime.now().strftime("%Y/%m/%d %H:%M:%S")
            )
        )
        out.write("#\n")
        out.write("# Structure file:     {}\n".format(strfile))
        out.write("# Topology file:      {}\n".format(topfile))
        out.write("# Bin file:           {}\n".format(binfile))
        out.write("# Bin file columns:   {}\n".format(cols))
        out.write("# Selection:          '{}'\n".format(sel_str))
        out.write("# Positive electrode: '{}'\n".format(surf_str))
        out.write("# Electrolyte:        '{}'\n".format(elyt_str))
        out.write("#\n")
        out.write("# Lattice properties of the positive electrode:\n")
        # Multiply by 1/10 to convert Angstrom to nm.
        out.write("# r0:         {:.9f} nm\n".format(r0 / 10))
        out.write("# flatside:   {} nm\n".format(flatside))
        out.write("#\n")
        out.write("# Force field parameters:\n")
        # Multiply by 1/10 to convert Angstrom to nm.
        out.write("# sigma_Li:   {:.9f} nm\n".format(sigma_Li / 10))
        out.write("# sigma_C:    {:.9f} nm\n".format(sigma_C / 10))
        out.write("# sigma_Li_C: {:.9f} nm\n".format(sigma_Li_C / 10))
        out.write("# r_eq:       {:.9f} nm\n".format(r_eq / 10))
        out.write("#\n")
        out.write("# Lithium ions in the first layer at the negative")
        out.write(" electrode.\n")
        out.write("# z_layer_min: {:.9f} nm\n".format(z_layer_min / 10))
        out.write("# Output in .gro file format, positions in nm, velocities")
        out.write(" in nm/ps)\n")
        out.write("# Number of lithium ions: {:d}\n".format(sel.n_atoms))
        out.write("# {:<8s} {:<9s}\n".format("Residue", "Atom"))
        out.write("#{:>4s}{:>5s}".format("num", "name"))
        out.write("{:>5s}{:>5s}".format("name", "num"))
        out.write("{:>8s}{:>8s}{:>8s}".format("x", "y", "z"))
        out.write("{:>8s}{:>8s}{:>8s}\n".format("v_x", "v_y", "v_z"))
        for atm in sel:
            out.write("{:>5d}{:<5s}".format(atm.resid, atm.resname))
            out.write("{:>5s}{:>5d}".format(atm.name, atm.index + 1))
            for pos in atm.position:
                out.write("{:>8.3f}".format(pos / 10))  # Angstrom -> nm
            for vel in atm.velocity:
                out.write("{:>8.4f}".format(vel / 10))  # Angstrom/ps -> nm/ps
            out.write("\n")
        out.write("\n")
        out.write("\n")
        out.write("# Suitable insertion points, i.e. hexagon center(s) with\n")
        out.write("# the fewest number of neighbors within r_max and no\n")
        out.write("# neighbors within r_min.\n")
        out.write(
            "# Number of Neighbors:  {:d}\n".format(n_neighbors[hex_ix_best])
        )
        # Multiply by 1/10 to convert Angstrom to nm.
        out.write("# z_pos:   {:.9f} nm\n".format(z_pos / 10))
        out.write("# z_shift: {:.9f} nm\n".format(z_shift / 10))
        out.write("# r_min:   {:.9f} nm\n".format(sigma_Li / 10))
        out.write("# r_max:   {:.9f} nm\n".format(r_cut / 10))
        out.write("#{:>7s}{:>8s}{:>8s}".format("x / nm", "y / nm", "z / nm"))
        out.write("   {:>6s} {:>17s}\n".format("hex_ix", "nearest_atom / nm"))
        for i, hex_ix in enumerate(hex_ixs):
            for pos in hex_centers[hex_ix]:
                out.write("{:>8.3f}".format(pos / 10))  # Angstrom -> nm
            out.write("   {:>6d}".format(hex_ix))
            out.write(" {:>17.9f}".format(min_dists[i] / 10))  # Angstrom -> nm
            if hex_ix == hex_ix_best:
                out.write("  # Insertion point (hexagon center with the")
                out.write(" furthest nearest-neighbor atom)")
            out.write("\n")
    print("Created {}".format(outfile))

    # Create a .gro file for each transferred lithium ion and save it to
    # a new directory.
    for atm in sel:
        u_copy = u.copy()
        u_copy.atoms[atm.index].position = insertion_point
        u_copy.atoms[atm.index].velocity = 0
        dir_name = "Li" + str(atm.index + 1) + "_transferred"
        os.mkdir(dir_name)
        outfile_gro = (
            args.settings + "_out_" + args.system + "_" + dir_name + ".gro"
        )
        outfile_gro = os.path.join(dir_name, outfile_gro)
        mdt.fh.backup(outfile_gro)
        u_copy.atoms.write(outfile_gro)
        print("Created {}".format(outfile_gro))

    print("{} done".format(script_name))
