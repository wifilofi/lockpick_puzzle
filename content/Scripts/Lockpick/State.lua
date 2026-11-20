local State = {}

function State.untimed()
    return {}
end

function State.timed(seconds, onComplete)
    return { duration = seconds, complete = onComplete }
end

return State
