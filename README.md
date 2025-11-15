# Actor Manager

**Actor Manager** is a high performance parallel task processing library for Roblox built on top of Parallel Luau. It manages worker actors using round-robin load balancing and automatic task queuing.

## Features

- **Round-Robin Load Balancing**: Distributes tasks evenly across all worker actors
- **Automatic Task Queuing**: FIFO queue system handles tasks assigned before actors are ready
- **Type-Safe**: Written in strict Luau with full type annotations
- **Simple API**: Easy to use API
- **Graceful Cleanup**: Easily able to create or destroy managers

## Installation

Download the source files and place them in your Roblox Studio project.

## Quick Start

### Basic Usage

```lua
local ActorManager = require(path.to.ActorManager)
local WorkerScript = script.WorkerTemplate

-- Create a manager with 32 workers
local Manager = ActorManager.new(WorkerScript, 32)

-- Assign a task with a callback
Manager:AssignTask("ProcessData", {Value = 123}, function(Result)
    print("Task completed:", Result)
end)

-- Clean up when done
Manager:Destroy()
```

### Creating Worker Scripts

Worker scripts must follow this pattern:

```lua
--!strict
--!optimize 2
--!native

local Actor = script:GetActor()
if not Actor then
    error("Worker script must be parented to an Actor")
end

local BindableEvent = Actor:FindFirstChild("Event")
if not BindableEvent then
    error("Worker missing BindableEvent")
end

-- Bind your task handlers
Actor:BindToMessageParallel("ProcessData", function(Payload, BindableEvent)
    -- Process your data here
    local Result = Payload.Value * 2
    
    -- Return the result
    BindableEvent:Fire(Result)
end)

-- Signal that worker is ready
BindableEvent:Fire("READY")
```

## API Reference

### Constructor

```lua
ActorManager.new(WorkerScript: Script, Amount: number?) -> ActorManager
```

Creates a new ActorManager instance.

**Parameters:**
- `WorkerScript`: The worker script template to clone for each actor
- `Amount`: Number of worker actors to create (default: 32)

**Returns:**
- `ActorManager`: A new manager instance

**Example:**
```lua
local Manager = ActorManager.new(script.WorkerTemplate, 16)
```

---

### AssignTask

```lua
ActorManager:AssignTask(ThreadName: string, TaskData: any, Callback: (any) -> ()) -> ()
```

Assigns a task to the next available worker actor using round-robin scheduling.

**Parameters:**
- `ThreadName`: The message topic that worker scripts bind to
- `TaskData`: Data to pass to the worker (can be any Luau type)
- `Callback`: Function called with the worker's result

**Example:**
```lua
Manager:AssignTask("ProcessData", {Value = 42}, function(Result)
    print("Processed result:", Result)
end)
```

---

### Destroy

```lua
ActorManager:Destroy() -> ()
```

Cleans up all actors, connections, and pending tasks. Call this when you're done with the manager.

**Example:**
```lua
Manager:Destroy()
```

## How It Works

Actor Manager uses Roblox's Actor system. It creates a pool of worker actors, sends tasks using round-robin scheduling, and manages callbacks through BindableEvents. Tasks assigned before actors are ready, are automatically queued and processed once initialization completes.

### Best Practices

- **Keep task payloads small** to minimize data transfer overhead
- **Avoid blocking operations** in worker scripts
- **Use `--!native` and `--!optimize 2`** flags in worker scripts

### When to Use

**Good for:**
- Heavy computational tasks (pathfinding, physics simulations)
- Parallel data processing (batch raycasting, terrain generation)
- Cryptographic operations

**Not recommended for:**
- Simple operations (< 1ms)
- Tasks requiring frequent synchronization
- UI updates or rendering operations

## FAQ

**How many actors should I use?**  
8-16 actors is usually enough.

**Can I use this with DataStoreService?**  
No, DataStore operations must run in serial context. Use actors for computation, then synchronize for DataStore access.

**What happens if I assign tasks before actors are ready?**  
Tasks are automatically queued and processed once all actors signal "READY".

**Can worker scripts share state?**  
No, each actor runs in isolation, although it is possible with modification.

## License

This project is licensed under the MIT License.