local M = {}

local ENABLED = true

local isAtBusStop = false
local currentStopTriggerName = nil
local currentUserCameraMode = nil
local justRevertedCamera = false

local function getIsTriggerForBusStop(triggerName)
  if not triggerName then return false end

  local obj = scenetree.findObject(triggerName)
  if obj then
    local ok, t = pcall(function() return obj.type end)
    if ok and t == "busstop" then
      return true
    end
  end

  -- fallback to support community maps
  local lower = triggerName:lower()
  return triggerName:match("^tmpl_bs_") ~= nil
      or lower:match("busstop") ~= nil
      or lower:match("^bs_") ~= nil
end

local function getPlayerVehicleID()
  local playerVehicle = be:getPlayerVehicle(0)
  return playerVehicle and playerVehicle:getID() or nil
end

-- fired whenever ANY object enters/exits ANY trigger
M.onBeamNGTrigger = function(data)
  if not ENABLED or not data then return end

  local pid = getPlayerVehicleID()
  if not pid or data.subjectID ~= pid then return end -- not our vehicle
  if not getIsTriggerForBusStop(data.triggerName) then return end

  if data.event == "enter" then
    log("I", "onBeamNGTrigger", "enter bus stop '" .. data.triggerName .. "'")
    currentStopTriggerName = data.triggerName
    isAtBusStop = true
  elseif data.event == "exit" and data.triggerName == currentStopTriggerName then
    log("I", "onBeamNGTrigger", "leave bus stop '" .. data.triggerName .. "'")
    currentStopTriggerName = nil
    isAtBusStop = false
  end
end

-- fired whenever active camera changes (eg. pressing C or when at bus stop)
M.onCameraModeChanged = function(cameraMode)
  if not ENABLED then return end
  
  -- if we *just* reverted the camera then this callback will trigger again
  if justRevertedCamera then
    justRevertedCamera = false
    return
  end

  -- if the bus challenge OR the user has manually switched the camera to the "bad" one
  if isAtBusStop and cameraMode == "onboard.rider" and cameraMode ~= currentUserCameraMode then
    justRevertedCamera = true
    log("I", "onCameraModeChanged", "revert camera from '" .. tostring(cameraMode) .. "' => '" .. tostring(currentUserCameraMode) .. "'")
    core_camera.setByName(0, currentUserCameraMode)
    return
  end

  if cameraMode ~= currentUserCameraMode then
    currentUserCameraMode = cameraMode
    log("I", "onCameraModeChanged", "remember camera '" .. tostring(currentUserCameraMode) .. "'")
  end
end

M.onVehicleSwitched = function()
  isAtBusStop = false
  currentStopTriggerName = nil
  justRevertedCamera = false
end

M.onClientEndMission = function()
  isAtBusStop = false
  currentStopTriggerName = nil
  justRevertedCamera = false
end

return M
