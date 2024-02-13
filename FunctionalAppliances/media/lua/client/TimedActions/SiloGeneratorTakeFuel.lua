require "TimedActions/ISBaseTimedAction"

SiloGeneratorTakeFuel = ISBaseTimedAction:derive("SiloGeneratorTakeFuel");

local function predicateEmptyPetrol(item)
	return item:hasTag("EmptyPetrol") or item:getType() == "EmptyPetrolCan"
end

function SiloGeneratorTakeFuel:isValid()
	local pumpCurrent = self.fuelTank:getPipedFuelAmount()
	return pumpCurrent > 0
end

function SiloGeneratorTakeFuel:waitToStart()
	self.character:faceLocation(self.square:getX(), self.square:getY())
	return self.character:shouldBeTurning()
end

function SiloGeneratorTakeFuel:update()
	self.petrolCan:setJobDelta(self:getJobDelta())
	self.character:faceLocation(self.square:getX(), self.square:getY())
	local actionCurrent = math.floor(self.itemStart + (self.itemTarget - self.itemStart) * self:getJobDelta() + 0.001)
	local itemCurrent = math.floor(self.petrolCan:getUsedDelta() / self.petrolCan:getUseDelta() + 0.001)
	if actionCurrent > itemCurrent then
		-- FIXME: sync in multiplayer
		local pumpCurrent = tonumber(self.fuelTank:getPipedFuelAmount())
		self.fuelTank:setPipedFuelAmount(pumpCurrent - (actionCurrent - itemCurrent))

		self.petrolCan:setUsedDelta(actionCurrent * self.petrolCan:getUseDelta())
    end

    self.character:setMetabolicTarget(Metabolics.LightWork);
end

function SiloGeneratorTakeFuel:start()
	if predicateEmptyPetrol(self.petrolCan) then
		local chr = self.character
		local emptyCan = self.petrolCan
		local newType = emptyCan:getReplaceType("PetrolSource") or "Base.PetrolCan"
		self.petrolCan = chr:getInventory():AddItem(newType)
		self.petrolCan:setUsedDelta(0)
		if chr:getPrimaryHandItem() == emptyCan then
			chr:setPrimaryHandItem(self.petrolCan)
		end
		if chr:getSecondaryHandItem() == emptyCan then
			chr:setSecondaryHandItem(self.petrolCan)
		end
		chr:getInventory():Remove(emptyCan)
	end

	self.petrolCan:setJobType(getText("ContextMenu_TakeGasFromPump"))
	self.petrolCan:setJobDelta(0.0)

	local pumpCurrent = tonumber(self.fuelTank:getPipedFuelAmount())
	local itemCurrent = math.floor(self.petrolCan:getUsedDelta() / self.petrolCan:getUseDelta() + 0.001)
	local itemMax = math.floor(1 / self.petrolCan:getUseDelta() + 0.001)
	local take = math.min(pumpCurrent, itemMax - itemCurrent)
	self.action:setTime(take * 50)
	self.itemStart = itemCurrent
	self.itemTarget = itemCurrent + take
	
	self:setOverrideHandModels(nil, self.petrolCan:getStaticModel())
	self:setActionAnim("TakeGasFromPump")

	self.sound = self.character:playSound("CanisterAddFuelSiphon")
end

function SiloGeneratorTakeFuel:stop()
	self.character:stopOrTriggerSound(self.sound)
	self.petrolCan:setJobDelta(0.0)
    	ISBaseTimedAction.stop(self);
end

function SiloGeneratorTakeFuel:perform()
	self.character:stopOrTriggerSound(self.sound)
	self.petrolCan:setJobDelta(0.0)
	local itemCurrent = math.floor(self.petrolCan:getUsedDelta() / self.petrolCan:getUseDelta() + 0.001)
	if self.itemTarget > itemCurrent then
		self.petrolCan:setUsedDelta(self.itemTarget * self.petrolCan:getUseDelta())
		-- FIXME: sync in multiplayer
		local pumpCurrent = self.fuelTank:getPipedFuelAmount()
		self.fuelTank:setPipedFuelAmount(pumpCurrent + (self.itemTarget - itemCurrent))
	end
    	-- needed to remove from queue / start next.
	ISBaseTimedAction.perform(self);
end

function SiloGeneratorTakeFuel:new(character, fuelTank, petrolCan, time)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character;
    	o.fuelTank = fuelTank;
	o.square = fuelTank:getSquare();
	o.petrolCan = petrolCan;
	o.stopOnWalk = true;
	o.stopOnRun = true;
	o.maxTime = time;
	return o;
end