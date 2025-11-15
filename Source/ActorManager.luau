--[=[
	ActorManager
	
	Manages worker actors for parallel task processing.
	Uses round robin assignment to assign tasks across multiple actors.
	Includes FIFO queue for tasks assigned before actors are ready.
	
	Worker Script Requirements:
		-- Must send "READY" signal on init:
			local Actor = script:GetActor()
			if not Actor then
				error("WorkerTemplate corrupted")
			end

			local BindableEvent = Actor:FindFirstChild("Event")
			if not BindableEvent then
				error("WorkerTemplate missing BindableEvent")
			end

			task.desynchronize()

			Actor:BindToMessageParallel("ProcessData", function(Payload, BindableEvent)
				BindableEvent:Fire("aaaaa")
			end)

			BindableEvent:Fire("READY")
	
	Example usage:
		local ActorManager = require(script.ActorManager)
		local WorkerScript = script.WorkerTemplate
		
		local Manager = ActorManager.new(WorkerScript, 4)
		
		Manager:AssignTask("ProcessData", {Value = 123}, function(Result)
			print("Task completed:", Result)
		end)
		
		Manager:Destroy()
--]=]

--!strict
--!optimize 2
--!native

type ActorData = {
	Instance: Actor,
	BindableEvent: BindableEvent,
	CallbackQueue: {(any) -> ()},
	Connection: RBXScriptConnection?
}

type QueuedTask = {
	ThreadName: string,
	TaskData: any,
	Callback: (any) -> ()
}

type ActorManagerImpl = {
	__index: ActorManagerImpl,
	new: (WorkerScript: Script, Amount: number?) -> ActorManager,
	CreateAllActors: (self: ActorManager, MaxActors: number) -> (),
	CreateActor: (self: ActorManager, Index: number) -> (),
	Push: (self: ActorManager) -> (),
	AssignTask: (self: ActorManager, ThreadName: string, TaskData: any, Callback: (any) -> ()) -> (),
	ProcessQueue: (self: ActorManager) -> (),
	Destroy: (self: ActorManager) -> ()
}

export type ActorManager = typeof(setmetatable({} :: {
	Actors: {ActorData},
	CurrentIndex: number,
	ActorCount: number,
	ExpectedActorCount: number,
	WorkerScript: Script?,
	Parent: Instance?,
	TaskQueue: {QueuedTask},
	QueueThread: thread?
}, {} :: ActorManagerImpl))

local CreateInstanceTree = require("@self/CreateInstanceTree")

local ActorManager = {} :: ActorManagerImpl
ActorManager.__index = ActorManager

function ActorManager.new(WorkerScript: Script, Amount: number?): ActorManager
	local ExpectedCount = Amount or 32
	local self = setmetatable({
		Actors = {},
		CurrentIndex = 1,
		ActorCount = 0,
		ExpectedActorCount = ExpectedCount,
		WorkerScript = WorkerScript,
		Parent = WorkerScript.Parent,
		TaskQueue = {},
		QueueThread = nil
	}, ActorManager)

	task.spawn(function()
		task.wait(3)
		self:CreateAllActors(ExpectedCount)
	end)

	return self
end

function ActorManager:CreateAllActors(MaxActors: number): ()
	for Index = 1, MaxActors do
		self:CreateActor(Index)
	end
end

function ActorManager:CreateActor(Index: number): ()
	local Actor = CreateInstanceTree({
		ClassName = "Actor",
		Properties = { Parent = self.Parent, Name = tostring(Index) }
	}) :: Actor

	local BindableEvent = CreateInstanceTree({
		ClassName = "BindableEvent",
		Properties = { Parent = Actor }
	}) :: BindableEvent

	local ActorData: ActorData = {
		Instance = Actor,
		BindableEvent = BindableEvent,
		CallbackQueue = {},
		Connection = nil
	}

	ActorData.Connection = BindableEvent.Event:Connect(function(Result)
		if Result == "READY" then
			self.ActorCount += 1
			self.Actors[self.ActorCount] = ActorData

			if self.ActorCount == self.ExpectedActorCount then
				self:ProcessQueue()
			end
			return
		end

		local Callback = table.remove(ActorData.CallbackQueue, 1)
		if Callback then
			Callback(Result)
		end
	end)

	CreateInstanceTree({
		Instance = self.WorkerScript,
		Properties = { Parent = Actor, Disabled = false },
	})
end

function ActorManager:Push()
	self.CurrentIndex += 1
	if self.CurrentIndex > self.ExpectedActorCount then
		self.CurrentIndex = 1
	end
end

function ActorManager:AssignTask(ThreadName: string, TaskData: any, Callback: (any) -> ()): ()
	if self.ActorCount < self.ExpectedActorCount then
		local QueueSize = #self.TaskQueue
		self.TaskQueue[QueueSize + 1] = {
			ThreadName = ThreadName,
			TaskData = TaskData,
			Callback = Callback
		}
		return
	end

	local Actor = self.Actors[self.CurrentIndex]
	if not Actor then
		error("No Actor?")
	end
	
	Actor.CallbackQueue[#Actor.CallbackQueue + 1] = Callback
	Actor.Instance:SendMessage(ThreadName, TaskData, Actor.BindableEvent)
	self:Push()
end

function ActorManager:ProcessQueue(): ()
	self.QueueThread = task.spawn(function()
		while #self.TaskQueue > 0 do
			print(#self.TaskQueue)
			local Task = table.remove(self.TaskQueue, 1)
			if not Task then
				error("No Task?")
			end

			local Actor = self.Actors[self.CurrentIndex]
			table.insert(Actor.CallbackQueue, Task.Callback)
			Actor.Instance:SendMessage(Task.ThreadName, Task.TaskData, Actor.BindableEvent)
			self:Push()
		end

		self.QueueThread = nil
	end)
end

function ActorManager:Destroy(): ()
	if self.QueueThread then
		task.cancel(self.QueueThread)
		self.QueueThread = nil
	end

	for _, ActorData in self.Actors do
		if ActorData.Instance then
			ActorData.Instance:Destroy()
			ActorData.Instance = nil :: any
		end

		if ActorData.Connection then
			ActorData.Connection:Disconnect()
			ActorData.Connection = nil
		end
	end

	self.Actors = {}
	self.ActorCount = 0
	self.TaskQueue = {}
end

return ActorManager