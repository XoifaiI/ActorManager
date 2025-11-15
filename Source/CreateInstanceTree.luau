--[=[
	CreateInstanceTree: Creates Instance hierarchies from table defs
	
	Example usage:
		local Tree = {
			ClassName = "Folder",
			Properties = { Name = "MyFolder" },
			Children = {
				{ ClassName = "Part", Properties = { Name = "MyPart" } }
			}
		}
		local Object = CreateInstanceTree(Tree)
--]=]

--!strict

type InstanceTree = {
	Instance: Instance?,
	ClassName: string?,
	Properties: { [string]: any }?,
	Children: { InstanceTree }?,
}

local function CreateInstanceTree(Tree: InstanceTree): Instance
	local Object: Instance
	if Tree.Instance then
		Object = Tree.Instance:Clone()
	else
		Object = Instance.new(Tree.ClassName :: string)
	end

	if Tree.Properties then
		for Property, Value in Tree.Properties do
			(Object :: any)[Property] = Value
		end
	end

	if Tree.Children then
		for _, ChildTree in Tree.Children do
			local ChildObject: Instance
			if ChildTree.Instance then
				ChildObject = ChildTree.Instance:Clone()
			else
				ChildObject = CreateInstanceTree(ChildTree)
			end
			ChildObject.Parent = Object
		end
	end

	return Object
end

return CreateInstanceTree