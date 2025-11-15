local ActorManager = require("@self/ActorManager")
local WorkerScript = script.WorkerTemplate

local Manager = ActorManager.new(WorkerScript, 32)

for i = 1, 100 do
	Manager:AssignTask("ProcessData", {Value = i}, function(Result)
		if i == Result then
			print("did all")
		end
	end)
end