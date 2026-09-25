local M = {}

local isBusMode = false
local isAtBusStop = false
local currentStopTriggerName = nil
local currentUserCameraMode = nil
local justRevertedCamera = false
local isGoingToSwitchCamera = false

local patchedMgr, origActivity

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
