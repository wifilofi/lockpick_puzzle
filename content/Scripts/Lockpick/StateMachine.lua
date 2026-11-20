local StateMachine = {}
StateMachine.__index = StateMachine


function StateMachine.new(states, owner, onTransition)
    return setmetatable({ states = states, owner = owner, onTransition = onTransition }, StateMachine)
end

function StateMachine:transitionTo(state)
    assert(self.states[state], "Unknown state: " .. tostring(state))
    local previous = self.currentState
    self.currentState, self.elapsed = state, 0
    if self.onTransition and previous ~= state then self.onTransition(previous, state) end
end


function StateMachine:isTimed()
    return self.states[self.currentState].duration ~= nil
end


function StateMachine:update(dt)
    local state = self.currentState
    local definition = self.states[state]
    if not definition.duration then return end
    self.elapsed = self.elapsed + dt
    local elapsed = self.elapsed
    local progress = math.min(elapsed / definition.duration, 1)
    if progress == 1 then definition.complete(self.owner) end

    return state, progress, elapsed
end

return StateMachine
