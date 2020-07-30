using StaticArrays

function path_planning(
    ub_x;
    nsteps = nothing,
    X_lb = [1.0, 2.2,  2.2, 3.4,  4.6, 5.8,  5.8,  7.0, 8.2, 8.4,  9.3, 8.4,  9.3, 8.4,  9.3],
    X_ub = [1.2, 2.4,  2.4, 3.6,  4.8, 6.0,  6.0,  7.2, 8.4, 9.3, 10.0, 9.3, 10.0, 9.3, 10.0],
    Y_lb = [0.0, 0.0,  6.0, 0.0,  1.0, 0.0,  7.0,  1.0, 0.0, 8.2,  7.0, 5.8,  4.6, 3.4,  2.2],
    Y_ub = [9.0, 5.0, 10.0, 9.0, 10.0, 6.0, 10.0, 10.0, 8.5, 8.6,  7.4, 6.2,  5.0, 3.8,  2.6],
    η = 0.2,
    plot = true
)
    frame = AB.HyperRectangle(SVector(0.0, 0.0, -pi - 0.4), SVector(ub_x, 10.0, pi + 0.4))
    init = AB.HyperRectangle(SVector(0.4, 0.4, 0.0), SVector(0.4, 0.4, 0.0))
    target = AB.HyperRectangle(SVector(ub_x - 1.0, 0.5, -100.0), SVector(ub_x - 0.4, 0.8, 100.0))
    x0 = SVector(0.0, 0.0, 0.0)
    h = SVector(η, η, η)
    X_grid = AB.NewGridSpaceHash(x0, h)
    AB.add_to_gridspace!(X_grid, frame, AB.OUTER)
    for i in eachindex(X_lb)
        box = AB.HyperRectangle(SVector(X_lb[i], Y_lb[i], frame.lb[3]), SVector(X_ub[i], Y_ub[i], frame.ub[3]))
        if box ⊆ frame && isempty(box ∩ init) && isempty(box ∩ target)
            AB.remove_from_gridspace!(X_grid, box, AB.OUTER)
        end
    end
    X_full = AB.NewSubSpace(X_grid)
    AB.add_to_subspace_all!(X_full)

    X_init = AB.NewSubSpace(X_grid)
    AB.add_to_subspace!(X_init, init, AB.OUTER)
    X_reach = AB.NewSubSpace(X_grid)
    AB.add_to_subspace!(X_reach, target, AB.OUTER)

    if plot
        fig = PyPlot.figure()
        ax = fig.gca(aspect = "equal")
        ax.set_xlim([-0.2, ub_x + 0.2])
        ax.set_ylim([-0.2, 10.2])

        Plot.subspace!(ax, 1:2, X_full, fa = 0.0)
        Plot.subspace!(ax, 1:2, X_init, fc = "green")
        Plot.subspace!(ax, 1:2, X_reach, fc = "yellow")
    end

    nsteps === nothing && return

    lb = SVector(-1.0, -1.0)
    ub = SVector(1.0, 1.0)
    u0 = SVector(0.0, 0.0)
    h = SVector(0.3, 0.3)
    U_grid = AB.NewGridSpaceHash(u0, h)
    AB.add_to_gridspace!(U_grid, AB.HyperRectangle(lb, ub), AB.OUTER)

    tstep = 0.3
    n_sys = 3
    n_bound = 3
    function F_sys(x, u)
          alpha = atan(tan(u[2])/2)
          return SVector(
              u[1]*cos(alpha + x[3])/cos(alpha),
              u[1]*sin(alpha + x[3])/cos(alpha),
              u[1]*tan(u[2]))
    end
    function L_bound(u)
          alpha = atan(tan(u[2])/2)
          return @SMatrix[
              0.0 0.0 u[1]/cos(alpha);
              0.0 0.0 u[1]/cos(alpha);
              0.0 0.0 0.0]
    end
    sys_noise = SVector(0.0, 0.0, 0.0)
    meas_noise = SVector(0.0, 0.0, 0.0)

    cont_sys = AB.NewControlSystemRK4(tstep, F_sys, L_bound, sys_noise, meas_noise, n_sys, n_bound)
    trans_map_sys = AB.NewTransitionMapHash(X_grid, U_grid, X_grid)
    @time AB.set_transitions_from_controlsystem!(trans_map_sys, cont_sys)

    trans_map_contr = AB.NewTransitionMapHash(X_grid, U_grid, X_grid)
    @time AB.set_controller_reach!(trans_map_contr, trans_map_sys, X_init, X_reach)

    if plot
        x0 = [0.4, 0.4, 0.0]
        Plot.trajectory_closed_loop!(ax, 1:2, cont_sys, trans_map_contr, x0, nsteps)
    end
end
