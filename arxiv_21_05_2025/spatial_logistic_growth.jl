using Random
using Plots

# --- Parameters ---
grid_size = 28           # Side length of the square grid
initial_population = 10  # Start with 10 agents
max_steps = 300          # Number of time steps
carrying_capacity = grid_size^2
r = 0.4              # Intrinsic growth rate

rng = MersenneTwister(1234)  # <--- Set your seed here (any integer)

# --- State ---
mutable struct Agent
    x::Int
    y::Int
    crossed_LR::Bool  # left to right
    crossed_RL::Bool  # right to left
    crossed_TB::Bool  # top to bottom
    crossed_BT::Bool  # bottom to top
end


# Functions for movement (up, down, left, right)
const directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]

# Initialize empty grid
function empty_grid(L)
    falses(L, L)
end

# Place agents randomly on grid
function place_agents!(agents, grid, N)
    free = [(i, j) for i in 1:grid_size, j in 1:grid_size]
    shuffle!(rng, free)
    for n in 1:N
        (x, y) = free[n]
        crossed_LR = false
        crossed_RL = false
        crossed_TB = false
        crossed_BT = false
        push!(agents, Agent(x, y, crossed_LR, crossed_RL, crossed_TB, crossed_BT))
        grid[x, y] = true
    end
end



# Check available neighbors
function free_neighbors(agent, grid)
    neighbors = Agent[]
    for (dx, dy) in directions
        nx, ny = agent.x + dx, agent.y + dy
        if 1 ≤ nx ≤ grid_size && 1 ≤ ny ≤ grid_size && !grid[nx, ny]
            push!(neighbors, Agent(nx, ny, false,false,false,false))
        end
    end
    return neighbors
end

# Agent tries to move
function move_agent!(agent, grid)
    candidates = free_neighbors(agent, grid)
    if !isempty(candidates)
        grid[agent.x, agent.y] = false
        chosen = rand(rng, candidates)
        prev_x, prev_y = agent.x, agent.y
        agent.x, agent.y = chosen.x, chosen.y
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

function reproduce_sexual!(agent, agents, grid, p_birth, all_agents, radius, alpha)
    # Only allow if agent has crossed any line
    if !(agent.crossed_LR || agent.crossed_RL || agent.crossed_TB || agent.crossed_BT)
        return
    end
    if has_mate(agent, all_agents, radius)
        n_local = count_neighbors(agent, all_agents, radius)
        p_local = p_birth * exp(-alpha * n_local)
        candidates = free_neighbors(agent, grid)
        if !isempty(candidates) && rand(rng) < p_local
            chosen = rand(rng, candidates)
            # Newborns start with all crossings = false
            push!(agents, Agent(chosen.x, chosen.y, false, false, false, false))
            grid[chosen.x, chosen.y] = true
        end
    end
end




# Visualization helper
myColor = :royalblue2


# --- Main simulation ---
function simulate_side_by_side_gif()
    agents = Agent[]
    grid = empty_grid(grid_size)
    place_agents!(agents, grid, initial_population)
    pop_hist = Int[]
    anim = @animate for step in 1:max_steps
        # Move
        for agent in shuffle(rng, agents)
            move_agent!(agent, grid)
        end
        N = length(agents)
        p_birth = r * (1 - N / carrying_capacity)
        new_agents = Agent[]
        radius = 2
        alpha = 0.1
        for agent in agents
            reproduce_sexual!(agent, new_agents, grid, p_birth, agents, radius, alpha)
        end
        append!(agents, new_agents)
        push!(pop_hist, length(agents))
        
        # Prepare plot with two panels **from the start**
        plt = plot(layout = (1,2), size = (800,400))
        
        # Panel 1: Agents on grid
        x = [a.x for a in agents]
        y = [a.y for a in agents]
        scatter!(plt[1], x, y;
            xlims=(1, grid_size), ylims=(1, grid_size),
            markersize=5, color=myColor, legend=false,
            aspect_ratio=:equal,
            title="Time step $step, Population: $(length(agents))",
            xlabel="x", ylabel="y"
        )
        # Panel 2: Population plot
        plot!(plt[2], 1:step, pop_hist[1:step];
            lw=2, color=myColor, label="Population",
            xlims=(1, max_steps), ylims=(0, carrying_capacity),
            xlabel="Time step", ylabel="Population",
            title="Population Dynamics"
        )
        plt
    end
    return pop_hist, anim
end

# Run!
pop_hist, anim = simulate_side_by_side_gif()
gif(anim, "images/logistic_side_by_side.gif", fps=10)
