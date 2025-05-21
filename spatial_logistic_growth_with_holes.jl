using Random
using Plots

# -------------------------------
# Parameters
# -------------------------------
grid_size = 30
initial_population = 10
max_steps = 300
r = 0.4
rng = MersenneTwister(1234)

# Define block (obstacle) positions (top-left corners)
num_blocks = 116
block_size = 1

# Randomly choose top-left corners for each block
all_possible = [(i, j) for i in 1:grid_size-block_size+1, j in 1:grid_size-block_size+1]
shuffle!(rng, all_possible)
block_positions = all_possible[1:num_blocks]

# Generate all blocked cells as a Set
blocked = Set{Tuple{Int,Int}}()
for (bx, by) in block_positions
    for dx in 0:block_size-1, dy in 0:block_size-1
        if 1 <= bx+dx <= grid_size && 1 <= by+dy <= grid_size
            push!(blocked, (bx+dx, by+dy))
        end
    end
end

# Adjust carrying capacity to available (non-blocked) cells
carrying_capacity = grid_size^2 - length(blocked)

# --- Agent Definition ---
mutable struct Agent1
    x::Int
    y::Int
    crossed_LR::Bool
    crossed_RL::Bool
    crossed_TB::Bool
    crossed_BT::Bool
end

const directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]

# Initialize empty grid, marking obstacles
function empty_grid(L, blocked)
    grid = falses(L, L)
    for (x, y) in blocked
        grid[x, y] = true
    end
    return grid
end

# Place agents in free (non-blocked, non-occupied) cells
function place_agents!(agents, grid, N)
    free = [(i, j) for i in 1:grid_size, j in 1:grid_size if !((i, j) in blocked) && !grid[i, j]]
    if length(free) < N
        error("Not enough free cells to place $N agents")
    end
    shuffle!(rng, free)
    for n in 1:N
        (x, y) = free[n]
        push!(agents, Agent1(x, y, false, false, false, false))
        grid[x, y] = true
    end
end

# Return list of free neighboring cells (not occupied, not blocked)
function free_neighbors(agent, grid, blocked)
    neighbors = Tuple{Int,Int}[]
    for (dx, dy) in directions
        nx, ny = agent.x + dx, agent.y + dy
        if 1 ≤ nx ≤ grid_size && 1 ≤ ny ≤ grid_size && !grid[nx, ny] && !((nx, ny) in blocked)
            push!(neighbors, (nx, ny))
        end
    end
    return neighbors
end

function move_agent!(agent, grid, blocked)
    candidates = free_neighbors(agent, grid, blocked)
    if !isempty(candidates)
        grid[agent.x, agent.y] = false
        chosen = rand(rng, candidates)
        prev_x, prev_y = agent.x, agent.y
        agent.x, agent.y = chosen[1], chosen[2]
        grid[agent.x, agent.y] = true

        # Left to Right and Right to Left
        if prev_x ≤ grid_size ÷ 2 && agent.x > grid_size ÷ 2
            agent.crossed_LR = true
        end
        if prev_x > grid_size ÷ 2 && agent.x ≤ grid_size ÷ 2
            agent.crossed_RL = true
        end
        # Top to Bottom and Bottom to Top
        if prev_y ≤ grid_size ÷ 2 && agent.y > grid_size ÷ 2
            agent.crossed_TB = true
        end
        if prev_y > grid_size ÷ 2 && agent.y ≤ grid_size ÷ 2
            agent.crossed_BT = true
        end
    end
end

# Check if agent has a neighbor within radius (potential mate)
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

# Count agents near a position (excluding self)
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

function reproduce_sexual!(agent, agents, grid, blocked, p_birth, all_agents, radius, alpha)
    if !(agent.crossed_LR || agent.crossed_RL || agent.crossed_TB || agent.crossed_BT)
        return
    end
    if has_mate(agent, all_agents, radius)
        n_local = count_neighbors(agent, all_agents, radius)
        p_local = p_birth * exp(-alpha * n_local)
        candidates = free_neighbors(agent, grid, blocked)
        if !isempty(candidates) && rand(rng) < p_local
            chosen = rand(rng, candidates)
            push!(agents, Agent1(chosen[1], chosen[2], false, false, false, false))
            grid[chosen[1], chosen[2]] = true
        end
    end
end

# --- Plotting with Obstacles ---
myColor = [:royalblue2 :tomato]
function plot_agents(agents, step, pop_hist, blocked)
    x = [a.x for a in agents]
    y = [a.y for a in agents]
    xb = [i for (i, j) in blocked]
    yb = [j for (i, j) in blocked]
    plt = scatter(x, y; xlims=(1, grid_size), ylims=(1, grid_size), title="Time step $step,  Population: $(length(agents))",
                  markersize=5, legend=false, aspect_ratio=:equal, c=myColor[2], grid=false)
    if !isempty(xb)
        scatter!(xb, yb; markercolor=:black, markersize=5, alpha=0.7, markerstrokewidth=0, marker=:rect)
    end
    return plt
end

# --- Main simulation ---
function simulate_with_obstacles_side_by_side()
    agents = Agent1[]
    grid = empty_grid(grid_size, blocked)
    place_agents!(agents, grid, initial_population)
    pop_hist = Int[]
    anim = @animate for step in 1:max_steps
        # Move agents
        for agent in shuffle(rng, agents)
            move_agent!(agent, grid, blocked)
        end
        # Reproduce
        N = length(agents)
        p_birth = r * (1 - N / carrying_capacity)
        new_agents = Agent1[]
        radius = 2
        alpha = 0.1
        for agent in agents
            reproduce_sexual!(agent, new_agents, grid, blocked, p_birth, agents, radius, alpha)
        end
        append!(agents, new_agents)
        push!(pop_hist, length(agents))

        # --- Panel 1: Agents + obstacles ---
        x = [a.x for a in agents]
        y = [a.y for a in agents]
        xb = [i for (i, j) in blocked]
        yb = [j for (i, j) in blocked]
        plt = plot(layout = (1,2), size = (850,400))
        scatter!(plt[1], x, y; xlims=(1, grid_size), ylims=(1, grid_size), 
            markersize=5, color=myColor[2], legend=false, 
            aspect_ratio=:equal, grid=false,
            title="Step $step, Population: $(length(agents))", xlabel="x", ylabel="y")
        if !isempty(xb)
            scatter!(plt[1], xb, yb; markercolor=:black, markersize=5, alpha=0.7, markerstrokewidth=0, marker=:rect)
        end
        # --- Panel 2: Population curve ---
        plot!(plt[2], 1:step, pop_hist[1:step], lw=2, color=:firebrick1, label="Population",
            xlims=(1, max_steps), ylims=(0, carrying_capacity),
            xlabel="Time Step", ylabel="Population",
            title="Population Dynamics")
        plt
    end
    return pop_hist, anim
end

# --- Run side-by-side simulation ---
pop_hist, anim = simulate_with_obstacles_side_by_side()
gif(anim, "images/logistic_population_with_blocks_side_by_side.gif", fps=10)