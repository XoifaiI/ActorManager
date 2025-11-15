--!strict
--!optimize 2
--!native

local Actor = script:GetActor()
if not Actor then
	error("WorkerTemplate corrupted")
end

local BindableEvent = Actor:FindFirstChild("Event")
if not BindableEvent then
	error("WorkerTemplate missing BindableEvent")
end

Actor:BindToMessageParallel("ProcessData", function(Payload, BindableEvent)
	BindableEvent:Fire(Payload.Value)
end)

BindableEvent:Fire("READY")