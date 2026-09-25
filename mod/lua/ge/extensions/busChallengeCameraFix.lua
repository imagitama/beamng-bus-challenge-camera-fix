local M = {}

local isBusMode = false
local isAtBusStop = false
local currentStopTriggerName = nil
local currentUserCameraMode = nil
local justRevertedCamera = false
local isGoingToSwitchCamera = false

local patchedMgr, origActivity
 
-- works for bus stops in West Coast USA but not always in others like Italy
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
  if not data then return end
  
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

-- beamng has "managers" that manage the flow of state
-- they are notified when the state changes eg. when you stop at a bus stop
-- to intercept these state changes we must monkeypatch the managers
local function attachToManager(mgr)
  log("I", "attach", "Attaching to manager '" .. tostring(mgr.id or "?") .. "'...")

  -- TODO: support multiple managers (not sure why the game would have them but w/e)
  if not mgr or patchedMgr == mgr then
    log("W", "attach", "Already attached to manager")
    return
  end

  -- could happen when a manager is created for the mission but the activity hasn't loaded yet
  local activity = mgr.activity
  if not activity then
    log("E", "attach", "Manager is missing an activity")
    return
  end

  -- ensure we nil these later to avoid memory leaks
  patchedMgr = mgr
  origActivity = activity

  local origStarted = activity.onFlowgraphStateStarted
  local origStopped = activity.onFlowgraphStateStopped

  -- activity.onFlowgraphStateStarted = function(self, name, state, transData)
  --   if origStarted then origStarted(self, name, state, transData) end
  --   extensions.hook('custom_onFlowgraphStateStarted', mgr, name, state, transData) -- hoping the devs add this for us
  -- end

  activity.onFlowgraphStateStopped = function(self, name, state, transData)
    if origStopped then origStopped(self, name, state, transData) end
    extensions.hook('custom_onFlowgraphStateStopped', mgr, name, state, transData) -- hoping the devs add this for us
  end

  log("I", "attach", "Attached to manager '" .. tostring(mgr.id or "?") .. "' successfully")
end

local function attachToManagers()
  local managers = core_flowgraphManager.getAllManagers()
  local count = 0
  for _ in pairs(managers) do
    count = count + 1
  end

  log("I", "attachToManagers", "Attach to " .. count .. " managers")

  for id, mgr in pairs(managers) do
    attachToManager(mgr)
    break
  end
end

-- M.onExtensionLoaded = function()
--   log("I", "onExtensionLoaded", "Extension loaded")
--   attachToManagers()
-- end

-- M.onScenarioLoaded = function(scenario)
--   log("I", "onScenarioLoaded", "Scenario '" .. scenario.name .. "' loaded")
--   attachToManagers()
-- end

-- M.onMissionScreenReady = function(mode) -- 'startScreen'
--   log("I", "onMissionScreenReady", "Ready!")
--   attachToManagers()
-- end

local function cleanup()
  -- prevent any memory leaks by removing our references
  patchedMgr = nil
  origActivity = nil
  -- general cleanup
  isBusMode = false
  isAtBusStop = false
  currentStopTriggerName = nil
  currentUserCameraMode = nil
  justRevertedCamera = false
  isGoingToSwitchCamera = false
end

M.onAnyMissionChanged = function(status, mission, userSettings)
  log("I", "onAnyMissionChanged", "Mission state '" .. status .. "' with mission '" .. mission.name .. "'")

  -- eg "levels.italy.buslines.routes.101a"
  if string.find(mission.name, "buslines", 1, true) then
    if status == "started" then
      isBusMode = true
      attachToManagers()
    elseif status == "stopped" then
      isBusMode = false
      cleanup()
    end
  end
end

-- M.onClientStartMission = function()
--   log("I", "onClientStartMission", "It is starting")
-- end

-- M.onClientPostStartMission = function()
--   log("I", "onClientPostStartMission", "Attaching to managers...")
--   attachToManagers()
-- end

local function onFlowgraphStateStarted(mgr, name, state, transData)
  -- log("I", "onFlowgraphStateStarted", name)
end

M.custom_onFlowgraphStateStarted = function(mgr, name, state, transData)
  -- onFlowgraphStateStarted(mgr, name, state, transData)
end

local function onFlowgraphStateStopped(mgr, name, state, transData)
  -- log("I", "onFlowgraphStateStopped", name)

  if name == "Go To Stop" or name == "PickPassengers" then
    log("I", "onFlowgraphStateStopped", "about to try and force camera!")
    isGoingToSwitchCamera = true
  end
end

M.custom_onFlowgraphStateStopped = function(mgr, name, state, transData)
  onFlowgraphStateStopped(mgr, name, state, transData)
end

-- fired whenever active camera changes (eg. pressing C or when at bus stop)
M.onCameraModeChanged = function(cameraMode)
  if not isBusMode then return end
  
  -- if we *just* reverted the camera then this callback will trigger again
  if justRevertedCamera then
    justRevertedCamera = false
    return
  end

  if isGoingToSwitchCamera then
    isGoingToSwitchCamera = false
    
    if currentUserCameraMode then
      justRevertedCamera = true
      log("I", "onCameraModeChanged", "reverting camera from '" .. tostring(cameraMode) .. "' => '" .. tostring(currentUserCameraMode) .. "'")
      core_camera.setByName(0, currentUserCameraMode)
    else
      log("I", "onCameraModeChanged", "cannot revert: no camera mode")
    end
    return
  end

  if cameraMode ~= currentUserCameraMode then
    currentUserCameraMode = cameraMode
    log("I", "onCameraModeChanged", "remember camera '" .. tostring(currentUserCameraMode) .. "'")
  end
end

return M
