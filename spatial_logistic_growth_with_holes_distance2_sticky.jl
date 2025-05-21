using Random
using Plots

# -------------------------------
# Parameters
# -------------------------------

grid_size = 30
initial_population = 4
max_steps = 300
r = 0.4

rng = MersenneTwister(1234)  # <--- Set your seed here (any integer)

# Define block (obstacle) positions (top-left corners)
num_blocks = 116  # <--- Number of blocks you want
block_size = 1                  # Each block is block_size × block_size

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
    pause::Int   # Number of steps agent is paused for (default 0)
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
function place_agents!(agents, grid, N, blocked)
    free = [(i, j) for i in 1:grid_size, j in 1:grid_size if !grid[i, j]]
    shuffle!(rng, free)
    for n in 1:N
        (x, y) = free[n]
        push!(agents, Agent1(x, y, 0))   # pause=0 at start
        grid[x, y] = true
    end
end


# Return list of free neighboring cells (not occupied, not blocked)
function free_neighbors(agent, grid, blocked)
    neighbors = Agent1[]
    for (dx, dy) in directions
        nx, ny = agent.x + dx, agent.y + dy
        if 1 ≤ nx ≤ grid_size && 1 ≤ ny ≤ grid_size && !grid[nx, ny] && !( (nx, ny) in blocked)
            push!(neighbors, Agent1(nx, ny, 0))
        end
    end
    return neighbors
end

# function move_agent!(agent, grid, blocked)
#     if agent.pause > 0
#         agent.pause -= 1
#         return  # Agent is paused; skip movement
#     end
#     candidates = free_neighbors(agent, grid, blocked)
#     if !isempty(candidates)
#         grid[agent.x, agent.y] = false
#         chosen = rand(candidates)
#         agent.x, agent.y = chosen.x, chosen.y
#         grid[agent.x, agent.y] = true
#     else
#         # Try to move in a random direction (even if it's blocked)
#         # If chosen direction is blocked, set pause = 1
#         dirs = shuffle(directions)
#         for (dx, dy) in dirs
#             nx, ny = agent.x + dx, agent.y + dy
#             if 1 ≤ nx ≤ grid_size && 1 ≤ ny ≤ grid_size && ((nx, ny) in blocked)
#                 agent.pause = 50  # Pause for one step
#                 return
#             end
#         end
#         # Otherwise, agent remains in place
#     end
# end
function move_agent!(agent, grid, blocked, block_pause_time)
    if agent.pause > 0
        agent.pause -= 1
        return  # Agent is paused; skip movement
    end
    # Pick a random direction (try only once per step)
    dx, dy = rand(rng, directions)
    nx, ny = agent.x + dx, agent.y + dy

    if 1 ≤ nx ≤ grid_size && 1 ≤ ny ≤ grid_size
        if (nx, ny) in blocked
            agent.pause = block_pause_time  # Step into a block: pause!
            return
        elseif !grid[nx, ny]
            # Move if the cell is free and not blocked
            grid[agent.x, agent.y] = false
            agent.x, agent.y = nx, ny
            grid[nx, ny] = true
            return
        end
    end
    # If chosen cell is out of bounds or occupied, just stay in place, no pause
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
            dist = abs(agent.x - other.x) + abs(agent.y - other.y) # Manhattan distance
            if dist ≤ radius
                count += 1
            end
        end
    end
    return count
end

function reproduce_sexual!(agent, agents, grid, blocked, p_birth, all_agents, radius, alpha)
    if has_mate(agent, all_agents, radius)
        n_local = count_neighbors(agent, all_agents, radius)
        p_local = p_birth * exp(-alpha * n_local)
        candidates = free_neighbors(agent, grid, blocked)
        if !isempty(candidates) && rand(rng) < p_local
            chosen = rand(rng,candidates)
            push!(agents, Agent1(chosen.x, chosen.y, 0))  # Newborns start with pause=0
            grid[chosen.x, chosen.y] = true
        end
    end
end


# --- Plotting with Obstacles ---
function plot_agents(agents, step, pop_hist, blocked)
    x = [a.x for a in agents]
    y = [a.y for a in agents]
    # Plot obstacles as red squares
    xb = [i for (i, j) in blocked]
    yb = [j for (i, j) in blocked]
    plt = scatter(x, y; xlims=(1, grid_size), ylims=(1, grid_size), title="Step $step - Population: $(length(agents))", 
                  markersize=7, legend=false, aspect_ratio=:equal, c=:blue, grid=false)
    if !isempty(xb)
        scatter!(xb, yb; markercolor=:red, markersize=10, alpha=0.4, markerstrokewidth=0)
    end
    return plt
end

# --- Main simulation ---
function simulate_with_obstacles()
    agents = Agent1[]
    grid = empty_grid(grid_size, blocked)
    place_agents!(agents, grid, initial_population, blocked)
    pop_hist = Int[]
    anim = @animate for step in 1:max_steps
        # Move agents
        for agent in shuffle(rng, agents)
            # move_agent!(agent, grid, blocked)
            block_pause_time = 1  # or any value you want
        move_agent!(agent, grid, blocked, block_pause_time)
        end
        # Reproduce
        N = length(agents)
        p_birth = r * (1 - N / carrying_capacity)
        new_agents = Agent1[]
        radius = 1   # mating/neighborhood radius
        alpha = .1

        for agent in agents
            reproduce_sexual!(agent, new_agents, grid, blocked, p_birth, agents, radius, alpha)
        end

        append!(agents, new_agents)
        push!(pop_hist, length(agents))
        plot_agents(agents, step, pop_hist, blocked)
    end
    return pop_hist, anim
end

# --- Run simulation ---
pop_hist, anim = simulate_with_obstacles()

# --- Save gif ---
gif(anim, "logistic_population_with_blocks.gif", fps=10)

# --- Plot population curve ---
plot(1:length(pop_hist), pop_hist, xlabel="Step", ylabel="Population", 
    label="Population", lw=2, legend=true, 
    title="Population Dynamics (With Obstacles)")
