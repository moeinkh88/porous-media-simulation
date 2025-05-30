using Random
using Plots
using Measures

# --------- Simulation parameters ----------
grid_size = 28           # no-obstacle grid
grid_size2 = 30          # obstacles grid
initial_population = 8
max_steps = 300
r = 0.2
TRAP_WAIT = 5            # Number of time steps to be trapped
rng = MersenneTwister(123)

# --------- Obstacles setup ----------
num_blocks = 116
block_size = 1
all_possible = [(i, j) for i in 1:grid_size2-block_size+1, j in 1:grid_size2-block_size+1]
shuffle!(rng, all_possible)
block_positions = all_possible[1:num_blocks]
blocked = Set{Tuple{Int,Int}}()
for (bx, by) in block_positions
    for dx in 0:block_size-1, dy in 0:block_size-1
        if 1 <= bx+dx <= grid_size2 && 1 <= by+dy <= grid_size2
            push!(blocked, (bx+dx, by+dy))
        end
    end
end
carrying_capacity1 = grid_size^2
carrying_capacity2 = grid_size2^2 - length(blocked)

# --------- Agent definitions ----------
mutable struct Agent
    x::Int
    y::Int
end
mutable struct Agent1
    x::Int
    y::Int
    trap_timer::Int
    was_trapped::Bool
end

const directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]

# --------- Initial position logic (new) ---------
function generate_matched_positions(N, grid_size, blocked, rng)
    # Only consider positions in [1:grid_size, 1:grid_size] and not blocked
    available = [(i, j) for i in 1:grid_size, j in 1:grid_size if !((i, j) in blocked)]
    if length(available) < N
        error("Not enough available spots in the overlap region!")
    end
    shuffle!(rng, available)
    return available[1:N]
end

# --------- Common agent logic ----------
function count_neighbors(agent, agents, radius)
    count = 0
    for other in agents
        if other !== agent
            dist = abs(agent.x - other.x) + abs(agent.y - other.y)
            if dist ≤ radius
                count += 1
            end
        end
    end
    return count
end
function has_mate(agent, agents, radius)
    for other in agents
        if other !== agent
            dist = abs(agent.x - other.x) + abs(agent.y - other.y)
            if dist ≤ radius
                return true
            end
        end
    end
    return false
end

# --------- No obstacle logic ----------
function empty_grid(L)
    falses(L, L)
end
function free_neighbors_noobs(agent, grid)
    neighbors = Agent[]
    for (dx, dy) in directions
        nx, ny = agent.x + dx, agent.y + dy
        if 1 ≤ nx ≤ grid_size && 1 ≤ ny ≤ grid_size && !grid[nx, ny]
            push!(neighbors, Agent(nx, ny))
        end
    end
    return neighbors
end
function move_agent_noobs!(agent, grid)
    candidates = free_neighbors_noobs(agent, grid)
    if !isempty(candidates)
        grid[agent.x, agent.y] = false
        chosen = rand(rng, candidates)
        agent.x, agent.y = chosen.x, chosen.y
        grid[agent.x, agent.y] = true
    end
end
function reproduce_noobs!(agent, agents, grid, p_birth, all_agents, radius, alpha)
    n_local = count_neighbors(agent, all_agents, radius)
    p_local = p_birth * exp(-alpha * n_local)
    candidates = free_neighbors_noobs(agent, grid)
    if !isempty(candidates) && rand(rng) < p_local
        chosen = rand(rng, candidates)
        push!(agents, Agent(chosen.x, chosen.y))
        grid[chosen.x, chosen.y] = true
    end
end

# --------- Obstacles logic ----------
function empty_grid_obs(L, blocked)
    grid = falses(L, L)
    for (x, y) in blocked
        grid[x, y] = true
    end
    return grid
end
function free_neighbors_obs(agent, grid, blocked)
    neighbors = Tuple{Int,Int}[]
    for (dx, dy) in directions
        nx, ny = agent.x + dx, agent.y + dy
        if 1 ≤ nx ≤ grid_size2 && 1 ≤ ny ≤ grid_size2 && !grid[nx, ny] && !((nx, ny) in blocked)
            push!(neighbors, (nx, ny))
        end
    end
    return neighbors
end

function is_adjacent_to_obstacle(agent, blocked, grid_size)
    for (dx, dy) in directions
        nx, ny = agent.x + dx, agent.y + dy
        if 1 ≤ nx ≤ grid_size && 1 ≤ ny ≤ grid_size && ((nx, ny) in blocked)
            return true
        end
    end
    return false
end

function move_and_trap_agent_obs!(agent, grid, blocked)
    if agent.trap_timer > 0
        agent.trap_timer -= 1
        agent.was_trapped = true
        return  # still trapped
    end
    # Only trap if NOT just released from a trap
    if is_adjacent_to_obstacle(agent, blocked, grid_size2) && !agent.was_trapped
        agent.trap_timer = TRAP_WAIT - 1  # start waiting, count this as first wait
        agent.was_trapped = true
        return
    end
    # If just released from trap, let agent move at least once, then re-activate trapping logic
    agent.was_trapped = false
    candidates = free_neighbors_obs(agent, grid, blocked)
    if !isempty(candidates)
        grid[agent.x, agent.y] = false
        chosen = rand(rng, candidates)
        agent.x, agent.y = chosen[1], chosen[2]
        grid[agent.x, agent.y] = true
    end
end

function reproduce_obs!(agent, agents, grid, blocked, p_birth, all_agents, radius, alpha)
    if agent.trap_timer > 0
        return
    end
    n_local = count_neighbors(agent, all_agents, radius)
    p_local = p_birth * exp(-alpha * n_local)
    candidates = free_neighbors_obs(agent, grid, blocked)
    if !isempty(candidates) && rand(rng) < p_local
        chosen = rand(rng, candidates)
        push!(agents, Agent1(chosen[1], chosen[2], 0, false))
        grid[chosen[1], chosen[2]] = true
    end
end

# --------- Simulate both in lockstep ----------
function simulate_both(init_positions)
    # Initialize agents using identical starting positions
    agents1 = [Agent(x, y) for (x, y) in init_positions]
    grid1 = empty_grid(grid_size)
    for a in agents1
        grid1[a.x, a.y] = true
    end
    agents2 = [Agent1(x, y, 0, false) for (x, y) in init_positions]
    grid2 = empty_grid_obs(grid_size2, blocked)
    for a in agents2
        grid2[a.x, a.y] = true
    end
    # Histories for plotting
    pop_hist1 = Int[]
    pop_hist2 = Int[]
    states1 = Vector{Tuple{Vector{Int},Vector{Int}}}()
    states2 = Vector{Tuple{Vector{Int},Vector{Int}}}()
    for step in 1:max_steps
        # --- No obstacles
        for agent in shuffle(rng, agents1)
            move_agent_noobs!(agent, grid1)
        end
        N1 = length(agents1)
        p_birth1 = r * (1 - N1 / carrying_capacity1)
        new_agents1 = Agent[]
        for agent in agents1
            reproduce_noobs!(agent, new_agents1, grid1, p_birth1, agents1, 2, 0.1)
        end
        append!(agents1, new_agents1)
        push!(pop_hist1, length(agents1))
        x1 = [a.x for a in agents1]
        y1 = [a.y for a in agents1]
        push!(states1, (copy(x1), copy(y1)))
        # --- With obstacles
        for agent in shuffle(rng, agents2)
            move_and_trap_agent_obs!(agent, grid2, blocked)
        end
        N2 = length(agents2)
        p_birth2 = r * (1 - N2 / carrying_capacity2)
        new_agents2 = Agent1[]
        for agent in agents2
            reproduce_obs!(agent, new_agents2, grid2, blocked, p_birth2, agents2, 2, 0.1)
        end
        append!(agents2, new_agents2)
        push!(pop_hist2, length(agents2))
        x2 = [a.x for a in agents2]
        y2 = [a.y for a in agents2]
        push!(states2, (copy(x2), copy(y2)))
    end
    return states1, pop_hist1, states2, pop_hist2
end

# --------- Make composite animation ----------
function composite_animation(states1, pop_hist1, states2, pop_hist2, blocked)
    max_steps = length(pop_hist1)
    xb = [i for (i, j) in blocked]
    yb = [j for (i, j) in blocked]
    anim = @animate for step in 1:max_steps
        x1, y1 = states1[step]
        x2, y2 = states2[step]
        plt = plot(layout = @layout([a b; c]), size = (1000,800), margin=2mm)
        # Top left: spatial no obstacles
        scatter!(plt[1], x1, y1; xlims=(1, grid_size), ylims=(1, grid_size),
            markersize=5, color=:royalblue2, legend=false, aspect_ratio=:equal,
            title="No Obstacles (step $step, N=$(length(x1)))",
            xlabel="x", ylabel="y", grid=false)
        # Top right: spatial with obstacles
        scatter!(plt[2], x2, y2; xlims=(1, grid_size2), ylims=(1, grid_size2),
            markersize=5, color=:tomato, legend=false, aspect_ratio=:equal,
            title="With Obstacles (step $step, N=$(length(x2)))",
            xlabel="x", ylabel="y", grid=false)
        if !isempty(xb)
            scatter!(plt[2], xb, yb; markercolor=:black, markersize=5, alpha=0.7, markerstrokewidth=0, marker=:rect)
        end
        # Bottom: population curves
        plot!(plt[3], 1:step, pop_hist1[1:step]; lw=2, color=:royalblue2, label="No Obstacles",
            xlims=(1, max_steps), ylims=(0, max(maximum(pop_hist1), maximum(pop_hist2))),
            xlabel="Time step", ylabel="Population", legend=:bottomright)
        plot!(plt[3], 1:step, pop_hist2[1:step]; lw=2, color=:tomato, label="With Obstacles")
                plt
    end
    return anim    
end
        
        # --------- Run everything ----------
init_positions = generate_matched_positions(initial_population, grid_size, blocked, rng)
states1, pop_hist1, states2, pop_hist2 = simulate_both(init_positions)
anim = composite_animation(states1, pop_hist1, states2, pop_hist2, blocked)
gif(anim, "images/comparison_spatial_and_population5.gif", fps=10)