###
Author: Praneeth Kolichala
Copyright (c) unofficially 2012-2013
Version: Beta 1.1.0
New in this version:
    - controls
    - Modules
    - All tags include "*"
    - Changed moveRight, moveLeft, etc. to be methods of a gameObject rather than an instance
    - @trigger method
    - Added @unbindCollision and @off
###
"use strict"
if not jQuery?
    throw new Error "jQuery is not defined"

$ = jQuery
error = (string, deep = no) ->
    if deep then throw new Error string
    else console?.error? string
    return
warn = (string) ->
    console?.warn? string
class GameObjectArray extends Array
    constructor: (original) ->
        @push item for item in original
    on: ->
        for obj in this
            obj.on arguments...
        @
    off: ->
        for obj in this
            obj.off arguments...
        @
    unbindCollision: ->
        for obj in this
            obj.unbindCollision arguments...
        @
    collides: ->
        for obj in this
            obj.collides arguments...
        @
Idea = (arg, n, d, f) ->
    theType = $.type arg
    nType = $.type n
    isListOfNumbers = ///
    ^ # Start the string
    (?:
    \d # A list of numbers only contains numbers and commas
    ,? # Comma
    )+ # Many times
    $ # End string
    ///
    if arg in allObjects and n in allRooms # If arg is one of the objects created by Idea.gameObject, return all instances of that object
        return n.allInstances[arg.objectId]
    else if arg in allObjects and (nType is "undefined" or n is "current")
        return Idea arg, room
    else if theType is "undefined" or theType is "null" # If no arg is provided, return allObjects
        return allObjects
    else if theType is "number" and nType is "undefined" # If arg is an id number, return that object
        return allObjects[arg]
    else if theType is "number" and n is "current"
        return Idea Idea arg
    else if theType is "number" and n in allRooms # If arg is an id number, but a room is provided, we know we are looking for an instance of that room
        return Idea(Idea(arg), n)
    else if theType is "string"
        switch arg
            when "iterate" # If we are iterating
                Idea.apply ["iterate forward"].concat [].slice.call(arguments, 1) # Use default (iterate forward)
            when "iterate forward" # Iterate starting from the beginning
                insts = Idea n, d
                for inst in insts
                    f.call inst
            when "iterate backward" # Iterate starting from the end
                insts = Idea n, d
                for i in [insts.length...0]
                    inst = insts[i - 1]
                    f.call inst
            else
                if isListOfNumbers.test arg # If arg is a list of numbers, we can assume that they are gameObject ids.
                    if nType is "undefined" # If a room isn't provided, return the raw gameObjects in a modified array
                        b = (Idea(parseInt(i, 10)) for i in arg.split(","))
                        return new GameObjectArray b
                    else if n is "current" or n in allRooms # If a room is provided, return the instances in a modified array
                        b = (parseInt(i, 10) for i in arg.split(","))
                        newInsts = new InstanceArray()
                        for obj in b
                            for inst in Idea obj, n
                                newInsts.push inst
                        return newInsts
                else if theType is "string" and nType is "undefined" # If a different string is provided, assume it's the tag of a gameObject
                    b = byTags[arg]
                    if not b?
                        error "Bad tag name" unless settings.suppressTagWarnings
                        return
                    return new GameObjectArray b # If no room is provided
                else if theType is "string" and (n is "current" or n in allRooms)
                    b = byTags[arg]
                    if not b?
                        error "Bad tag name" unless settings.suppressTagWarnings
                    newInsts = new InstanceArray() # If a room is provided
                    for obj in b
                        for inst in Idea obj, n
                            newInsts.push inst
                    return newInsts
                else
                    error "Unrecognizable arguments", yes
Idea.version = "beta"
fromCharCode = (chr) ->
    letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    from32to40 = "space,page up,page down,end,home,left,up,right,down".split ","
    ret = switch chr
        when 8 then "backspace"
        when 9 then "tab"
        when 13 then "enter"
        when 16 then "shift"
        when 17 then "ctrl"
        when 18 then "alt"
        when 20 then "caps lock"
        when 27 then "esc"
        when 45 then "insert"
        when 46 then "delete"
        when 188 then ","
        when 190 then "."
        when 191 then "/"
        when 192 then "`"
        when 219 then "["
        when 220 then "\\"
        when 222 then "'"
        else null
    unless ret
        if 32 <= chr <= 40 then ret = from32to40[chr - 32]
        if 48 <= chr <= 57 then ret = (chr-48)+""
        if 65 <= chr <= 90 then ret = letters[chr-65]
        if 112 <= chr <= 123 then ret = "f" + (chr-111)
    ret

room = null
useDom = no # Warning: useDom is still in very very ALPHA mode.
game_screen = null
gameWidth = null
gameHeight = null
game = null
backgroundCanvas = null
byTags = {}
modules = []
# A module is telling IdeaJS to call this code once game.play occurs
# For example
# Idea.module("platformer").on("collision-with-platform", function() {...});
# For all future gameObjects created with a tag 'platformer', they will get the collision-with-platform event
class Module
    on: (events, fn, overwrite) ->
        selector = @selector
        buffer = @buffer
        buffer[selector] ?= []
        buffer[selector].push [events, fn, overwrite]
        this
    constructor: (@selector) ->
        modules.push this
        @buffer = {}
Idea.module = (tag) ->
    new Module tag
class InstanceArray extends Array
    constructor: -> super,
    attr: (str, value) ->
        if value? or $.type(str) is "object"
            for inst in this
                inst.attr arguments...
            this
        else
            this[0].attr arguments...
    props = [
        'x', 'y', 'vx', 'vy', 'useBackCan', 'deactivateOut', 'sprite', 'create', 'begin step', 'draw', 'step', 'end step', 'events', 'collision', 'visible'
    ]
    fns = ['trigger', 'destroy', 'moveUp', 'moveDown', 'moveRight', 'moveLeft', 'fourDirections', 'animate']
    for prop in props
        do (prop) =>
            Object.defineProperty @prototype, prop,
                set: (val) ->
                    for i in this
                        i[prop] = val
                    return
                get: (val) ->
                    this[0]?[prop]
            return
    for fn in fns
        do (fn) =>
            this::[fn] = ->
                for inst in this
                    inst[fn] arguments...
                return this
            return
Idea.init = (xGameWidth, xGameHeight, xUseDom = no, root = "body") ->
    unless xUseDom
        # If useDom is false then append to canvases to root
        xGame_screen = $("<canvas width=#{xGameWidth} height=#{xGameHeight}>").css
            "position": "absolute"
            "z-index": 0

        xBackgroundCanvas = $("<canvas width=#{xGameWidth} height=#{xGameHeight}>").css
            "position": "absolute"
            "z-index": -1

        $(root)
            .append(xBackgroundCanvas)
            .append(xGame_screen)
        useDom = no
        [game_screen, backgroundCanvas] = [xGame_screen[0], xBackgroundCanvas[0]]
    else
        $(root).css
            position: "absolute"
            width: xGameWidth
            height: xGameHeight
        game_screen = $(root)[0]
        useDom = yes
    [gameWidth, gameHeight] = [xGameWidth, xGameHeight]
    do ->
        # (c) by https://gist.github.com/paulirish/1579671
        # RequestAnimationFrame polyfill
        lastTime = 0
        vendors = ['ms', 'moz', 'webkit', 'o']
        for vendor in vendors
            break if window.requestAnimationFrame
            window.requestAnimationFrame = window[vendor + 'RequestAnimationFrame']
            window.cancelAnimationFrame = window[vendor + 'CancelAnimationFrame'] or window[vendor + 'CancelRequestAnimationFrame']
     
        unless window.requestAnimationFrame
            window.requestAnimationFrame = (callback, element) ->
                currTime = new Date().getTime()
                timeToCall = Math.max(0, 16 - (currTime - lastTime))
                id = window.setTimeout (-> callback(currTime + timeToCall)), timeToCall
                lastTime = currTime + timeToCall
                id
            window.cancelAnimationFrame = (id) -> clearTimeout id
    gameInterval = 0
    fps = 0
    lastUpdate = Date.now()
    fpsFilter = 50
    basicFunctionsStart() # Start basic functions
    r.renderBackPic() for r in allRooms # Now that the body has loaded, we can let the rooms load their background picture
    game =
        play: ->
            # Load all modules
            for module in modules
                for selector, values of module.buffer
                    if module.buffer.hasOwnProperty selector
                        objs = Idea selector
                        for value in values
                            objs.on value...
            # Start the fun
            fun = =>
                gameInterval = requestAnimationFrame fun
                if Idea.assetsLoaded is assets.length # Check if all assets have loaded
                    unless @loaded
                        @loaded = yes
                        @finishLoad()
                    room?.refresh() # Refresh the room
                    basicFunctionsEnd() # End basic functions
                    # Calculate fps
                    thisFrameFPS = 1000 / ((now = Date.now()) - lastUpdate)
                    fps += (thisFrameFPS - fps) / fpsFilter
                    lastUpdate = now
                else
                    @load Idea.assetsLoaded / assets.length # Otherwise, call the load function
            gameInterval = requestAnimationFrame fun
        fps: -> if fps isnt fps then fps = 60 else fps # Hack for checking if fps is NaN
        pause: ->
            cancelAnimationFrame gameInterval
        load: (progress) ->
            # console.log("Loading: " + (progress * 100) + "%") --> User defined function
            ctx = game_screen.getContext "2d"
            ctx.save()
            ctx.fillStyle = settings.loadColor
            ctx.strokeStyle = settings.loadColor
            x = gameWidth / 2 - 50
            y = gameHeight / 2 - 25
            ctx.fillRect x, y, progress * 100, 50
            ctx.strokeRect x, y, 100, 50
            ctx.restore()
        finishLoad: ->
            room?.refreshBackground?()
        loaded: no
    game

# Functions to get certain values
# Would make them getters instead of functions
# but perhaps not all browsers support this
 
Idea.game = -> game

Idea.settings = settings =
    bufferDestroy: yes
    bufferRoomGoto: yes
    suppressAudioWarnings: no
    suppressTagWarnings: no
    suppressAlarmWarnings: no
    loadColor: "red"
Idea.controls = controls =
    keyControls: (fnDown, fnUp) ->
        $(document).keydown(fnDown).keyup(fnUp)
    mouseControls: (fnDown, fnUp, fnMove) ->
        $(game_screen).mousedown(fnDown).mouseup(fnUp).mousemove(fnMove)

Idea.support = support =
    audio: "Audio" of window
    canvas: if document.createElement("canvas")?.tagName? then yes else no

Idea.getScreen = ->
    game_screen

Idea.getCanvasContext = ->
    game_screen.getContext? "2d"

Idea.getBackCanContext = ->
    backgroundCanvas.getContext? "2d"

Idea.getBackgroundCanvas = -> backgroundCanvas
Idea.gameWidth = -> gameWidth
Idea.gameHeight = -> gameHeight
Idea.defineSettings = (newSettings) ->
    $.extend settings, newSettings
Idea.allObjects = allObjects = []
trigger = (caller, methods, args...) ->
    fns = caller[methods]
    switch $.type(fns)
        when "function" then fns.apply caller, args
        when "array"
            for fn in fns
                fn.apply caller, args
        else no
triggerCollision = (caller, methods, args...) ->
    switch $.type(methods)
        when "function" then methods.apply caller, args
        when "array"
            for method in methods
                method.apply caller, args
        else no


newAngles = (x, y, degrees, centerX, centerY) ->
    # Compute the bounding box coordinates of a rotated sprite
    theta = degrees / 360 * (Math.PI * 2)
    x2 = centerX + (x - centerX) * Math.cos(Math.PI * 2 - theta) + (y - centerY) * Math.sin(Math.PI * 2 - theta)
    y2 = centerY - (x - centerX) * Math.sin(Math.PI * 2 - theta) + (y - centerY) * Math.cos(Math.PI * 2 - theta)
    [x2, y2]
Idea.gameObject = (args, tags = []) ->
    tags.push "*" unless "*" in tags
    class gmInstance # A single instance
        constructor: (gx, gy) ->
            if @sprite?.useDom then @statics = @useBackCan = no # If we useDom, then having statics or useBackCan doesn't make sense
            @sprite?.createDiv() # Creates the div element (will silently fail if useDom = false)
            # By default, assign width to sprite's width
            # It probably isn't a good idea to let IdeaJS estimate the width of the sprite too
            # because if you define the gameObject before the sprite loads, then the width will be 0
            # (Same for height)
            @width ?= @sprite?.width
            @height ?= @sprite?.height
            # Deactivate out means that if the instance is outside the view or isn't visible, we don't want to waste CPU cycles calling it's events
            # useBackCan means that, since the instance never moves, draw it once to the background canvas.
            # These should be assigned to gameObjects like rocks, whose only purpose is to block the character -- they never move or change.
            # If useBackCan is true, that means that all instances should be created in room.create;
            # If an instance with useBackCan=true is moved, destroyed, or created, for it to show on screen, room.refreshBackground() must be called.
            # (Careful - room.refreshBackground() can be expensive)
            if @statics
                @deactivateOut = yes # Setting statics to true is really a shortcut for setting deactivateOut and useBackCan to true
                @useBackCan = yes

            # Add the instance to room.allInstances, so we have a reference to it
            room.allInstances[gmInstance.objectId].push @
            # If we use the background canvas, add us to room.staticInst
            room.staticInst.push @ if @useBackCan
            @animQueue = []
            @currentQueue = 0
            @constructor = gmInstance
            @prevX = @x = gx
            @prevY = @y = gy
            @vx = @vy = 0
            @created = no
            @imgAngle = 0
            @imgScaleX = @imgScaleY = 1
            @id = room.allInstances[gmInstance.objectId].length
        statics: no
        sprite: null
        visible: yes
        width: null
        deactivateOut: no
        useBackCan: no
        deactivateOut: no
        visible: yes
        animate: (props, frames = 200) ->
            @animQueue.push [props, frames]
            this
        attr: (str, value) ->
            if value? and $.type(str) is "string"
                this[str] = value
                this
            else if $.type(str) is "object"
                this[key] = str[key] for key of str when str.hasOwnProperty(key)
                this
            else
                @[str]
        nullified: no
        destroy: (buffer = settings.bufferDestroy) -> # Destroy an instance
            if buffer
                # If we are supposed to buffer, then let the room destroy us at the end of the frame
                # Buffering has many advantages:
                # 1) You can destroy many instances at once: Idea(myObj).destroy()
                # 2) Other objects that may rely on this one may throw errors; with buffering this doesn't happen
                room.toDestroy.push this
                return
            obj = @constructor # Grab the actual object
            $(".divSprite#{@sprite.id}:eq(#{@id - 1})")?.remove() if @sprite?.useDom # If the instance owns a div element, remove it.
            insts = Idea obj, room # Grab all other instances of this type
            ind = insts.indexOf @ # Find where this instance is located
            if @ in room.staticInst # If it is in staticInst, we must remove it from there too.
                ind2 = room.staticInst.indexOf @
                room.staticInst.splice ind2, 1
            insts.splice  ind, 1 # Remove the instance
            return
         mask: -> # If mask is specified then use that, otherwise...
            # To get the bounding box, we must use newangles find the rotated coordinates of its bounding box
            if @imgAngle is 0
                return {@x, @y, @width, @height} # Avoid extra computations
            newangles = newAngles @x, @y, @imgAngle, @x + @width/2, @y + @height/2 # Rotated coordinates of top left
            newangles2 = newAngles @x + @width, @y + @height, @imgAngle, @x + @width / 2, @y + @height / 2 # Rotated coordinates of bottom right
            newangles3 = newAngles @x, @y + @height, @imgAngle, @x + @width/2, @y + @height/2 # Rotated coordinates of bottom left
            newangles4 = newAngles @x + @height, @y, @imgAngle, @x + @width/2, @y + @height/2 # Rotated coordinates of top right
            objx = Math.min newangles[0], newangles2[0], newangles3[0], newangles4[0]
            objy = Math.min newangles[1], newangles2[1], newangles3[1], newangles4[1]
            return {
                x: objx
                y: objy
                width: (Math.max newangles[0], newangles2[0], newangles3[0], newangles4[0]) - objx
                height: (Math.max newangles[1], newangles2[1], newangles3[1], newangles4[1]) - objy
            }
        moveUp: ->
            @constructor.moveUp arguments...
            return this
        moveDown: ->
            @constructor.moveDown arguments...
            return this
        moveLeft: ->
            @constructor.moveLeft arguments...
            return this
        moveRight: ->
            @constructor.moveRight arguments...
            return this
        fourDirections: ->
            @constructor.fourDirections arguments...
            return this
        stopMovement: -> # Stops movement and jumps back to last position (that was presumably safe)
                @vx = @vy = 0
                @x = @prevX
                @y = @prevY
        glideTo: (ox, oy, speed = 1) ->
            # Start moving towards a spot
            # Does NOT automatically stop
            # Simply sets vx and vy accordingly
            [x, y] = [@x, @y]
            difX = x - ox
            difY = y - oy
            n = Math.sqrt((difX * difX + difY * difY) / (speed * speed))
            [@vx, @vy] = [difX / n, difY / n]
        draw: (ctx) ->
            # Draw the sprite
            @sprite?.draw ctx, @x, @y, @id
            # If we are the first instance, then refresh the sprite's animation
            @sprite?.refreshAnimation(room.allInstances[this.constructor.objectId][0] is this)
        collision: {}
        direction: (vx = @vx, vy = @vy) ->
            # Calculates the direction that the instance is traveling in
            degrees = Math.atan2(vy, vx) * 180 / Math.PI
            (((degrees + 360) % 360)) % 360
        speed: (vx = @vx, vy = @vy) ->
            # Calculates the total speed of the instance
            Math.sqrt vx * vx + vy * vy
        trigger: -> trigger this, arguments...
        events: ->
            # Calls all the events
            unless @created # If we haven't been created, then call the create method
                @created = yes
                trigger this, "create"
            # The begin step event is called every frame (before anything else.)
            trigger this, "begin step" # Call the begin step event
            ctx = game_screen.getContext '2d' unless useDom # Grab the context
            insideView = collisionRect @mask(), do -> # Check if we are inside the view
                    v = room.view()
                    x: v[0]
                    y: v[1]
                    width: gameWidth
                    height: gameHeight
            @visible = insideView
            if not insideView and @deactivateOut # If we are not inside the view and deactivateOut is true
                room.deactivated.push @ # Add this instance to the list of deactivated, remove the instance and exit
                insts = Idea gmInstance, room
                ind = insts.indexOf @
                insts.splice ind, 1
                if @sprite.useDom
                    $(".divSprite#{@sprite.id}:eq(#{@id - 1})").css "display", "none"
                return
            # If we are inside the view, the div was previously set to display: none, so make it block again.
            if insideView and @deactivateOut and useDom then $(".divSprite#{@sprite.id}:eq(#{@id - 1})").css "display", "block"
            if @draw? and not @useBackCan # If the draw method is there and we are using the foreground canvas
                if useDom # If we are using DOM elements, we can't perform transformations.
                    trigger this, "draw", game_screen
                else # Otherwise
                    ctx.save() # Save canvas state
                    ctx.translate @x + @width/2, @y + @height/2 # Translate such that the rotation occurs in the center
                    ctx.rotate @imgAngle * Math.PI / 180 # Translate by @imgAngle degrees
                    ctx.scale @imgScaleX, @imgScaleY
                    ctx.translate -(@x + @width/2), -(@y + @height/2) # Undo translate
                    trigger this, "draw", ctx
                    ctx.restore()
            # Nullified means that we no longer perform events, but we would like to still be drawn
            # This is useful for e.g. death or birth animations.
            if @nullified then return no
            # The step event occurs every frame
            trigger this, "step"
            toSplice = []
            queue = @animQueue[0]
            if queue
                [props, frames] = queue
                for prop, value of props
                    this[prop] += (value - this[prop]) / frames
                    if Math.abs(this[prop] - props[prop]) < 0.001
                        delete props[prop]
                queue[1]--
                if $.isEmptyObject(queue[0])
                    @animQueue.splice 0, 1
            for i of @collision ? {} # Loop though each key of @collision
                continue unless @collision.hasOwnProperty i # Skip properties inherited from Object.prototype
                obj = allObjects[parseInt i, 10]
                for inst in room.allInstances[obj.objectId]
                    continue if inst.nullified
                    c = collisionRect inst.mask(), @mask() # If a collision occurs between our mask and its mask
                    if c then triggerCollision this, @collision[i], inst, c # Then call the collision event(s)
            do =>
                # Do we intersect the room's boundary?
                if @x + @width > room.w then trigger this, "intersect boundary", "right"
                if @y + @height > room.h then trigger this, "intersect boundary", "bottom"
                if @x < 0 then trigger this, "intersect boundary", "left"
                if @y < 0 then trigger this, "intersect boundary", "top"
            do =>
                # Are we outside the room's view
                if @x > room.w then trigger this, "outside room", "right"
                if @x + @width < 0 then trigger this, "outside room", "left"
                if @y > room.h then trigger this, "outside room", "bottom"
                if @y + @height < 0 then trigger this, "outside room", "top"
            do =>
                theView =
                    x: room.view()[0]
                    y: room.view()[1]
                    left: room.view()[0] + gameWidth
                    bottom: room.view()[1] + gameHeight
                intr = @["intersect view"]
                outs = @["outside view"]
                # Intersect view
                if @x + @width > theView.left then trigger this, "intersect view", "right"
                if @y + @height > theView.bottom then trigger this, "intersect view", "bottom"
                if @x < theView.x then trigger this, "intersect view", "left"
                if @y < theView.y then trigger this, "intersect view", "top"
                # Outside view
                if @x > theView.w then trigger this, "outside view", "right"
                if @x + @width < theView.x then trigger this, "outside view", "left"
                if @y > theView.bottom then trigger this, "outside view", "bottom"
                if @y + @height < theView.y then trigger this, "outside view", "top"
            for key in Idea.globalKeysdown
                trigger this, "keydown-#{fromCharCode key}"
            for key in Idea.globalKeysup
                trigger this, "keyup-#{fromCharCode key}"
            for key in Idea.globalKeyspressed
                trigger this, "keypressed-#{fromCharCode key}"
            trigger this, "mousedown-#{Idea.globalMousedown}" if Idea.globalMousedown
            trigger this, "mousepressed-#{Idea.globalMousepressed}" if Idea.globalMousepressed
            trigger this, "mouseup-#{Idea.globalMouseup}" if Idea.globalMouseup

            @prevX = @x
            @prevY = @y
            # Automatically add velocity to x and y
            @x += @vx
            @y += @vy
            # The end step event occurs at the end of each instances events
            trigger this, "end step"
            return
        # (Now this refers to the gmInstance)
        allObjects.push this # Add gmInstance to our collection of gameObjects
        @objectId = allObjects.length - 1
        allRooms.forEach (v, i, l) -> # Add a new InstanceArray() to each room's allInstances. (That represents our instances)
            l[i].allInstances.push new InstanceArray()

        # Tags are a convenient way to refer to a gameObject
        # If two gameObjects both contain "enemy" in there tag definitions,
        # I can refer and bind events simply with
        # Idea("enemy").on("..", function() {
        # });

        for i in tags
            # Give a reference of us to byTags
            if byTags[i]? then byTags[i].push @
            else byTags[i] = [this]
        @on = (_events, fn, overwrite = no) ->
            # Binds new event or events seperated by ", "
            events = _events.split ", "
            isCollisionEvent = "collision-with-"
            for event in events
                # For each event
                if event.indexOf(isCollisionEvent) is 0
                    # If it is a collision event, let @collides handle it.
                    _with = event[isCollisionEvent.length..]
                    @collides _with, fn, overwrite
                    continue
                # Grab the prototype
                pr = @prototype[event]
                # If the event has never been defined before, or overwrite is true, simply write to prototype
                if not pr? or overwrite then @prototype[event] = fn
                # If the event has been written to once (it is a function,) then make it an array
                else if $.type(pr) is "function" then @prototype[event] = [pr, fn]
                # If it is already an array, then add fn to the array
                else if $.type(pr) is "array" then pr.push fn
                if room? # If room is defined (so Idea.init has been called and we are doing this inside of another event.)
                    # Go through all instances and delete any other copy of the event (so that it is reference prototype.)
                    for inst in Idea this, "current"
                        if inst.hasOwnProperty event
                            delete inst[event]
            this
        @collides = (_with, fn, overwrite = no) ->
            @collision ?= {}
            if ($.type(_with) is "function") then _with = _with.objectId.toString()
            w = _with.split ", "
            for obj in w
                if (parseInt obj, 10) is (parseInt obj, 10)
                    # obj is a number
                    pr = @prototype.collision[obj]
                    if not pr? or overwrite then @prototype.collision[obj] = fn
                    else if $.type(pr) is "function" then @prototype.collision[obj] = [pr, fn]
                    else if $.type(pr) is "array" then pr.push fn
                else
                    # obj is a tag name
                    objs = Idea obj
                    for oObj in objs
                        # for each gameObject in objs
                        pr = @prototype.collision[oObj.objectId]
                        if not pr? or overwrite then @prototype.collision[oObj.objectId] = fn
                        else if $.type(pr) is "function" then @prototype.collision[oObj.objectId] = [pr, fn]
                        else if $.type(pr) is "array" then pr.push fn
                if room?
                    for inst in Idea(this)
                        delete inst.collision
            this
        @moveUp = (speed = 1, callback, key = "up") -> # Shortcut to assign an event handler for moving up
            if $.type(callback) is "string" then key = callback
            @on "keydown-#{key}", ->
                @vy = -speed
                callback?("up")
            @on "keyup-#{key}", ->
                @vy = 0
            @
        @moveDown = (speed = 1, callback, key = "down") -> # Shortcut to assign an event handler for moving down
            if $.type(callback) is "string" then key = callback
            @on "keydown-#{key}", ->
                @vy = speed
                callback?("down")
            @on "keyup-#{key}", ->
                @vy = 0
            @
        @moveLeft = (speed = 1, callback, key = "left") -> # Shortcut to assign an event handler for moving left
            if $.type(callback) is "string" then key = callback
            @on "keydown-#{key}", ->
                @vx = -speed
                callback?("left")
            @on "keyup-#{key}", ->
                @vx = 0
            @
        @moveRight = (speed = 1, callback, key = "right") -> # Shortcut to assign an event handler for moving right
            if $.type(callback) is "string" then key = callback
            @on "keydown-#{key}", ->
                @vx = speed
                callback?("right")
            @on "keyup-#{key}", ->
                @vx = 0
            @
        @fourDirections = (speed, callback, keys = ["up", "down", "left", "right"]) ->
            # Shortcut to assign an event handler for moving in all four directions
            if $.type(callback) is "array" then keys = callback
            @
            .moveUp(speed, callback, keys[0])
            .moveDown(speed, callback, keys[1])
            .moveLeft(speed, callback, keys[2])
            .moveRight(speed, callback, keys[3])
            @
        # The arguments that are provided simply override the existing ones
        # So, any arguments that you define go directly to @prototype
        $.extend @prototype, args
        @off = (_events, method) ->
            events = _events.split ", "
            isCollisionEvent = "collision-with-"
            for event in events
                if event.indexOf(isCollisionEvent) is 0
                    _with = event[isCollisionEvent.length..]
                    @unbindCollision? _with, method
                else if method?
                    if method is @prototype[event] then @prototype[event] = null
                    else
                        for subFire, index in @prototype[event]
                            if subFire is method
                                @prototype[event].splice index, 1
                                break
                else
                    pr = @prototype[event]
                    if $.type(pr) is "function" then @prototype[event] = null
                    else if $.type(pr) is "array" then @prototype[event]?.splice 0, 9e9
            this
        @unbindCollision = (_with, method)  ->
            if $.type(_with) is "function" then _with = _with.objectId.toString()
            w = _with.split(", ")
            for obj in w
                if (parseInt obj, 10) is (parseInt obj, 10)
                    # obj is a number
                    pr = @prototype.collision[obj]
                    if method?
                        if pr is method then @prototype.collision[obj] = null
                        else
                            for subFire, ind in pr
                                if subFire is method
                                    @prototype[event].splice ind, 1
                                    break
                    else
                        if $.type(pr) is "function" then @prototype.collision[obj] = null
                        else if $.type(pr) is "array" then @prototype.collision[obj]?.splice 0, 9e9
                else
                    # obj is a tag name
                    objs = Idea obj
                    for oObj in objs
                        # for each gameObject in objs
                        @unbindCollision oObj, method
                if room?
                    for inst in Idea(this)
                        delete inst.collision
    gmInstance

# You probably won't need this function, but it returns the byTags object
# A better way to get the object(s) associated with a tag name is simply Idea(myTagName)
Idea.getByTags = -> byTags
Idea.assets = assets = []
Idea.assetsLoaded = 0
playingSounds = []
newAudio = ->
    (new Audio()) or document.createElement "Audio"
class Sound
    # TrackID is the default id that we'll go with if no other id is provided
    # Since there are multiple tracks,
    # mySound.play(0);
    # will play the audio located at mySound.tracks[0]
    # mySound.play();
    # mySound.play();
    # will play the audio located at mySound.tracks[0]
    # Then trackID becomes 1 and it will play mySound.tracks[1]
    # Then trackID becomes 2, so the next time you play it, it will play mySound.tracks[2]
    trackID: 0
    constructor: (src, numTracks = 3, onload) ->
        return unless support.audio # Silently fail if no audio support
        @unusedTracks = [] # The track ids that haven't been used
        @tracks = [] # All tracks
        @loadedTracks = []
        if $.type(src) is "object" then [src, numTracks, onload] = [src.source, src.tracks, src.onload]
        if $.type(numTracks) is "function" then [onload, numTracks] = [numTracks, 5]
        @loaded = no
        # @sound is the base audio from which the other audios are cloned
        # @sound is never actually played though
        @sound = newAudio()
        if $.type(src) is "array"
            maybes = [] # Favor probably over maybe
            for i in src
                ending = i.substr ((i.lastIndexOf ".") + 1)
                cpt = @sound.canPlayType "audio/#{ending}"
                if cpt is "probably" and ending isnt "wav" # Favor other types over wav (since wav files are generally big.)
                    src = i
                    break
                else if cpt is "maybe" or ending is "wav"
                    maybes.push i
            if $.type(src) is "array"
                src = maybes[0]
                if src.substr(src.lastIndexOf(".") + 1) is "wav" and maybes[1]?
                    src = maybes[1]
                if not src?
                    warn "No audio file formats were found applicable" unless settings.suppressAudioWarnings
                    src = src[0]
        $(@sound).on "canplaythrough", =>
            if @loaded then return
            Idea.assetsLoaded++
            @loaded = yes
            onload?.call @
            if @sound.duration > 5 and @sound.src.substr(@sound.src.lastIndexOf(".") + 1) is "wav"
                # Wav files are generally big
                # With bigger files, we don't want to load too much
                @tracks = [@sound]
                @unusedTracks = [0]
                warn "Wav files are too big to load many. (Only one track will be loaded.)
                Convert to ogg or mp3" unless settings.suppressAudioWarnings
            else
                for ii in [0...numTracks] by 1
                    # Load a new track until numTracks tracks have been loaded
                    @unusedTracks.push ii
                    @tracks[ii] = newAudio()
                    assets.push @tracks[ii]
                    do (ii) =>
                        $(@tracks[ii]).on "canplaythrough", =>
                            unless @loadedTracks[ii]
                                @loadedTracks[ii] = yes
                                Idea.assetsLoaded++
                            return
                        return
                    @loadedTracks[ii] = no
                    @tracks[ii].src = src
                    @tracks[ii].preload = on
            return
        @sound.src = src
        @sound.preload = on
        @sound.load()
        assets.push @sound
    play: (trackId = @trackID) ->
        unless @tracks[trackId]? # There are no tracks left
            error "Not enough tracks" unless settings.suppressAudioWarnings
            return
        @tracks[trackId].play() # Play the sound
        $(@tracks[trackId]).on "ended pause", =>
            @unusedTracks.push spliced unless spliced in @unusedTracks # When we end or pause, then whichever id we spliced from unusedTracks, we add back
            $(this).off "ended pause"
            @trackID = @unusedTracks[0]
        spliced = @unusedTracks.splice(@unusedTracks.indexOf(trackId), 1)[0] # 
        @trackID = @unusedTracks[0]
        trackId
    stop: (trackId) ->
        unless trackId?
            for track in @tracks
                track.pause()
        else
            @tracks[trackId].pause()
        @trackID = @unusedTracks[0]
        @unusedTracks
    loop: (trackId = @trackID) ->
        unless @tracks[trackId]? # There are no tracks left
            error "Not enough tracks" unless settings.suppressAudioWarnings
            return
        @tracks[trackId].loop = on
        @tracks[trackId].play()
        $(@tracks[trackId])
        .off("ended pause")
        .on "pause", =>
            @unusedTracks.push spliced
            $(this).off "ended pause"
        spliced = @unusedTracks.splice(@unusedTracks.indexOf(trackId), 1)[0]
        @trackID = @unusedTracks[0]
        trackId
Idea.Sound = Sound
Idea.playingSounds = -> playingSounds
Idea.alarms = alarms = []
# An alarm is a delay type function
# It works better than setTimeout, because it will
# pause when the game is paused.
# Also, it is step-based, so that it is independent of the fps
# A slower computer's gameplay will not be affected too much
class Alarm
    constructor: (frames, onFinish) ->
        alarms.push this # Add to Idea.alarms
        @onEnd = if onFinish? then [onFinish] else []
        @value = frames # Value
        @startValue = frames # When you start over, this is default value
    end: (fn) ->
        # The end function is used to add another function to @onEnd
        @onEnd.push fn
        this
    startOver: (frames = @startValue) ->
        # Will reset value to frames or @startValue
        @value = frames
        this
    trigger: ->
        # Calls each function in @onEnd
        for fn in @onEnd
            fn.call this
        this

Idea.Alarm = Alarm
Idea.removeAlarm = removeAlarm = (alarm) ->
    # Removes a given alarm
    allAlarms = alarms
    if $.type(alarm) is "number"
        # If alarm is a number, it must be an alarm id
        allAlarms.splice alarm, 1
    else
        # If alarm is an alarm, make sure it is in allAlarms, then remove it.
        if alarm not in allAlarms
            error("Alarm not found!") unless settings.suppressAlarmWarnings
            return
        allAlarms.splice allAlarms.indexOf(alarm), 1

Idea.removeAllAlarms = -> removeAlarm(0) while @alarms[0]
Idea.animation = (divider, x, y, width, height) ->
    # Animation should be inserted in the tiles property of a sprite
    if $.type(divider) is "object"
        {divider, x, y, width, height} = divider
        x ?= 0
        y ?= 0
    unless width? and height?
        width = x
        height = y
        x = y = 0
    [x + w, y, divider, height] for w in [0...width] by divider
class Sprite
    # A sprite is any image in the game
    # All sprites have a screen property
    # The screen property is a canvas that is redrawn onto the screen
    ids = 0
    setSize = (elem, width, height) ->
        # Set the size of the element
        if elem.tagName.toLowerCase() is "canvas"
            elem.width = width
            elem.height = height
        else
            $(elem).css {width, height, position: "absolute"}
    createRepeating = (args) ->
        # Repeats the element
        # Takes old canvas and applies it many times to newCanvas
        newCanvas = document.createElement "canvas"
        newCanvas.width = args.screen.width
        newCanvas.height = args.screen.height
        context = newCanvas.getContext "2d"
        pattern = context.createPattern args.screen, if args.repeating  is yes then "repeat" else args.repeating
        context.rect 0, 0, newCanvas.width, newCanvas.height
        context.fillStyle = pattern
        context.fill()
        newCanvas
        

    loadFunction = (args) ->
        # Takes a function and applies to the canvas
        args.fn(args.screen) # Call the function with the argument as the canvas
        newCanvas = args.screen # A direct reference to args.screen
        unless args._useDom or args.repeating is no
            # Eliminates the direct reference and instead replaces it with the repeating form
            # Does not usually work with function unless the width and height are manually set in args.fn
            newCanvas = createRepeating args
        newCanvas

    loadSrc = (args) ->
        # Takes a source and applies the loaded image onto a canvas
        img = new Image() # Create a new image
        newCanvas = args.screen # Direct referemce
        context = newCanvas.getContext "2d" unless args._useDom
        img.onload = =>
            # Once image loads, we must set the width and height (unless they were previously set)
            # However, it is not a good idea to allow IdeaJS to estimate the width and height
            # because, if you assign the sprite to a gameObject, the gameObject's width and height
            # will be equal to the sprite's (which hasn't loaded.)
            unless args.repeating
                @width = img.width unless @width?
                @height = img.height unless @height?
                newCanvas.width = @width
                newCanvas.height = @height
                if args._useDom then newCanvas.appendChild img else context.drawImage img, 0, 0, @width, @height
            else
                if args._useDom then error "DOM elements cannot have patterns", yes
                pattern = context.createPattern img, if args.repeating is yes then "repeat" else args.repeating
                context.rect 0, 0, @width, @height
                context.fillStyle = pattern
                context.fill()
            Idea.assetsLoaded += 1 # Increase the number of assets loaded
            args.onload?.apply this # Call the onload function
        img.src = args.source # Set the source
        assets.push img # Add it to assets
        img

    constructor: (args) ->
        @id = ids
        ids++
        # Allows for two syntaxes:
        # 1) new Sprite("mysource.png");
        # 2) new Sprite({
        #   source: "mysource.png",
        #   width: myWidth,
        #   height: myHeight,
        #   ...
        # });
        if $.type(args) is "string" then args = {
            source: args
        }
        {source, @width, @height, repeating, onload, @speed, _useDom, tilesize, tiles} = args
        # Set default values for repeating, @speed, _useDom, tilesize, and passArgs
        repeating ?= no
        @speed ?= 1
        _useDom ?= no
        tilesize ?= 1
        passArgs = {source, @width, @height, repeating, onload, @speed, _useDom, tilesize, tiles}
        # This is the canvas element / div (if using DOM) that to which we apply functions/images
        @screen = document.createElement if _useDom then "div" else "canvas"
        # Set width and height
        if @width? and @height?
            setSize @screen, @width, @height
        if $.type(source) is "function"
            # Load a function
            @type = "function"
            @screen = loadFunction.call this, {fn: source, @width, @height, repeating, onload, @speed, _useDom, tilesize, tiles, screen: @screen}
        else if tiles?
            # The tiles property allows to get a sprite from a certain area of a tileset.
            # The syntax is as follows:
            # new Sprite({
            #   source: "tileset.png",
            #   tilesize: 16,
            #   tiles: [x, y, width, height]
            # });
            # OR for an animation
            # new Sprite({
            #   source: "tileset.png",
            #   tilesize: 16,
            #   // --> Use Idea.animation as a shortcut for generating this array
            #   tiles: [[frame1.x, frame1.y, frame1.width, frame1.height], [frame2.x, frame2.y...]... ]
            # });
            if _useDom then error "Cannot use tiles with DOM elements", yes
            if $.type(tiles[0]) isnt "array" # Check if it isn't a tile animation
                # Simply load that section of the image
                offsetX = tiles[0] * tilesize # Calculate the x offset
                offsetY = tiles[1] * tilesize # Calculate the y offset
                # It is safe to use this method for estimating width and height, because it does not occur on image load
                @screen.width = @width = tiles[2] * tilesize
                @screen.height = @height = tiles[3] * tilesize
                _this = this
                newSource = new Sprite {
                    source # Same source:
                    onload: -> # Once it has loaded
                        @draw _this.screen.getContext("2d"), -offsetX, -offsetY, 1 # Draw it on OUR screen, so that we may have it
                }
                @type = "tileset"
            else
                # It's a tile animation
                @width ?= tiles[0][2] * tilesize
                @height ?= tiles[0][3] * tilesize
                # With each tile array, create a new sprite
                # This is the same as an array animation
                @imgs = tiles.map (tile) =>
                    new Sprite {source, @width, @height, repeating, onload, @speed, _useDom, tilesize, tiles: tile}
                @imgInd = 0
                @type = "animation"
        else if $.type(source) is "array"
            # This a basic animation where you're loading many frames from different sources (usually not recommended because of load time.)
            # For example:
            # new Sprite({
            #   source: ["frame1.png", "frame2.png", "frame3.png", "frame4.png"...]
            # });
            @type = "animation"
            if _useDom then error "Cannot create animation with DOM elements", yes
            # Load each source
            @imgs = source.map (src) =>
                new Sprite {source: src, @width, @height, repeating, onload, @speed, _useDom, tilesize, tiles: tiles}
            @imgInd = 0
        else if $.type(source) is "string"
            # Load some source like "mysource.png"
            @type = "src"
            loadSrc.call this, {source, @width, @height, repeating, onload, @speed, _useDom, tilesize, tiles, screen: @screen}
        @useDom = _useDom
    draw: (id, x, y, divId) ->
        unless @useDom
            # We are using a canvas
            switch @type
                when "src", "function", "tileset"
                    id.drawImage @screen, x, y # Draw the image if it is just a normal canvas
                when "animation"
                    @imgs[Math.floor @imgInd].draw arguments... # If it is an animation, draw the next screen
        else
            theDiv = $ ".divSprite#{@id}:eq(#{divId - 1})"
            theDiv.css
                left: "#{x - room.view()[0]}px"
                top: "#{y - room.view()[1]}px"
    refreshAnimation: (isFirst) ->
        # Refreshes the animation (increases imgInd by speed, where speed is any number from 0 to (# of frames),
        # 0 meaning it doesn't animate at all and (# of frames) meaning it animates so quickly you can't see it animating
        # (Basically, it doesn't animate at all.))
        # You usually want speed at 0.5 or 0.7
        if @type is "animation" and isFirst
            # If we are not the first instance, then don't animate, (since imgInd was already increased by a previous instance.)
            @imgInd = (@imgInd + @speed) % @imgs.length
    createDiv: ->
        # Creates the div element with class divSprite#{id}, appends it to $(game_screen)
        if not @useDom then return
        thisDiv = $(@screen).clone(yes)
        thisDiv.attr "class", "divSprite#{@id}"
        root = if useDom then game_screen else "body"
        $(root).append thisDiv
        $(thisDiv).css position: "absolute"
        return

Idea.Sprite = Sprite
collisionRect = (a, b) ->
    # Tests for a collision between a (with x, y, width, and height) and b (with x, y, width, and height)
    # Returns either "top", "bottom", "left", "right", or false (if there is no collision)
    unless (a.x < b.x + b.width and a.x + a.width > b.x and a.y < b.y + b.height and a.y + a.height > b.y) then return no
    top = b.y + b.height - a.y
    bottom = a.y + a.height - b.y
    right = a.x + a.width - b.x
    left = b.x + b.width - a.x
    min = Math.min top, bottom, left, right
    return switch min
        when top then "top"
        when bottom then "bottom"
        when right then "right"
        when left then "left"
        else "top"

basicFunctionsStart = ->
    # Creating assigning variables such as globalMouseX, globalMouseY etc.
    basicFunctionsEnd()
    Idea.globalMouseX = Idea.globalMouseY = 0
    Idea.globalKeysdown = []
    Idea.globalMousedown = no
    # We use mDown to keep track of the previous mouse events
    # So when a keydown event occurs, if mDown doesn't contain that code, we know that it was the first time that key was pressed
    # On key up, we reset mDown, so it can happen again
    # This is for globalKeypressed, which occurs only once per keypress, that is, if you press the space bar many times, it will occur many times
    # However, if you press and hold the key, it will only occur once (until you release it.)
    mDown = []
    # Assign the events
    # Bind them using jQuery

    $(game_screen)
    .contextmenu -> # Prevent right clicks on the canvas screen
        no
    .dblclick (e) -> # Prevent double clicks from their default action
        no
    mouseMoveHandler = (e) -> # Caputre mousemove events and assign to globalMouseX and globalMouseY
        Idea.globalMouseX = e.offsetX or e.pageX - $(this).offset().left
        Idea.globalMouseY = e.offsetY or e.pageY - $(this).offset().top
        no
    mouseDownHandler = (e) ->
        Idea.globalMousepressed = Idea.globalMousedown = if e.which is 3 then "right" else "left" # Mousedown events
        no
    mouseUpHandler = (e) -> # Mouseup events
        Idea.globalMousedown = no
        Idea.globalMouseup = if e.which is 3 then "right" else "left"
        no
    keyDownHandler = (e) -> # When key is pressed
        # Abbreviations
        d = Idea.globalKeysdown
        p = Idea.globalKeyspressed
        w = e.which
        unless w in d # If the char code isn't in globalKeysdown, add it to globalKeysdown
            d.push w
        unless w in p or w in mDown # If the key isn't in keyspressed or mDown, it must be the first time the key was pressed
            p.push w # so add it to keyspressed and mDown
            mDown.push w
        no
    keyUpHandler = (e) ->
        # Key up event so take out w from mDown
        # mDown.splice mDown.indexOf(w), 1
        d = Idea.globalKeysdown
        u = Idea.globalKeysup
        w = e.which
        mDown.splice mDown.indexOf(w), 1
        unless w in u
            u.push w
        d.splice d.indexOf(w), 1
        no
    
    controls.mouseControls mouseDownHandler, mouseUpHandler, mouseMoveHandler
    controls.keyControls keyDownHandler, keyUpHandler
    return
basicFunctionsEnd = ->
    # Resets globalKeysup, globalKeyspressed, globalMousepressed, and globalMouseup
    Idea.globalKeysup = []
    Idea.globalKeyspressed = []
    Idea.globalMousepressed = Idea.globalMouseup = no
    return
Idea.math = math =
    # The distance function is the basic formula for calculating the distance between two points.
    # You can provide 4 points, an object and two points, two points and an object, or two objects.
    # So, for example, you could do this
    # Idea.gameObject({
    #   events...
    # }).collides(myOtherObject, function(myOtherInstance) {
    #   // Since you and myOtherInstance have x and y properties, you can use distance
    #   var distance = Idea.math.distance(this, myOtherInstance);
    # });
    distance: (x1, y1, x2, y2) ->
        if $.type(x1) is "object" and $.type(y1) is "object"
            [x1, y1, x2, y2] = [x1.x, x1.y, y1.x, y1.y]
        else if $.type(x1) is "object" and $.type(y1) is "number" and $.type(x2) is "number"
            [x1, y1, x2, y2] = [x1.x, x1.y, y1, x2]
        else if $.type(x1) is "number" and $.type(y1) is "number" and $.type(x2) is "object"
            [x1, y1, x2, y2] = [x1, y1, x2.x, x2.y]
        Math.sqrt (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2)
    # Intersect is a wrapper for the local collisionRect
    # It checks if 2 rectangles intersect
    # You can provide 8 points, an object and four points, four points and an object, or two objects.
    # The objects must contain x, y, width, and height properties.
    intersect: (x1, y1, w1, h1, x2, y2, w2, h2) ->
        if $.type(x1) is "object" and $.type(y1) is "object" then [obj1, obj2] = [x1, y1]
        if $.type(x1) is "object" and $.type(y1) is $.type(w1) is $.type(h1) is $.type(x2) is "number"
            obj1 = x1
            obj2 =
                x: y1
                y: w1
                width: h1
                height: x2
        if $.type(x1) is $.type(y1) is $.type(w1) is $.type(h1) is "number" and $.type(x2) is "object"
            obj1 =
                x: x1
                y: y1
                width: w1
                height: h1
            obj2 = x2
        if $.type(x1) is "number" and $.type(h2) is "number"
            obj1 =
                x: x1
                y: y1
                width: w1
                height: h1
            obj2 =
                x: x2
                y: y2
                width: w2
                height: h2
        return collisionRect obj1, obj2

# This is the array with all rooms created by Room
# We can access the index with room.id
# So if room.constructor === Room then:
# Idea.allRooms[room.id] === room // <-- true 
Idea.allRooms = allRooms = []
class Room
    constructor: (args = {}) ->
         [@persistent, @background, backPic, @w, @h, repeating, @useBackCanvas] = [args.persistent, args.background, args.backPic
            args.width ? (gameWidth ? 0), args.height ? (gameHeight ? 0), args.repeating ? yes
            args.useBackCanvas ? yes]
         @toDestroy = []
         @following = {}
         @roomToGoTo = off
         @allInstances = []
         @staticInst = []
         @deactivated = []
         allRooms.push @
         @id = allRooms.length - 1
         @dynamic = []
         @trx = 0
         @try = 0
         @renderBackPic = ->
             # Loads the background canvas
             @largeBackPics = @w > gameWidth * 9 and @h > gameHeight * 9 and backPic?
             if  @largeBackPics and backPic? and not useDom
                largePic = new Image()
                @smallCan = []
                # Split background into smaller canvases because background is too large --- Note, this doesn't work well yet
                that = this
                largePic.onload = ->
                    for row in [0...largePic.width] by gameWidth
                        n = that.smallCan.length
                        that.smallCan.push []
                        for column in [0...largePic.height] by gameHeight
                            c = document.createElement 'canvas'
                            c.width = gameWidth
                            c.height = gameHeight
                            ctx = c.getContext '2d'
                            cw = if row + gameWidth > @width then @width - row else gameWidth
                            ch = if column + gameHeight > @height then @height - column else gameHeight
                            ctx.drawImage @, row, column, cw, ch, 0, 0, cw, ch
                            that.smallCan[n].push c
                    return
                if repeating
                    (new Sprite backPic, @w, @h, repeating, ->
                        largePic.src = @c.toDataURL())
             else if backPic? then @backPic = new Sprite source: backPic, width: @w, height: @h, repeating: repeating

    refreshBackground: ->
        # A fairly expensive call -
        # Refreshes the background onto the background canvas
        # Also refreshes all instances in @staticInst
        # (because they useBackCan.)
        # Used for performance improvements
        if @useBackCanvas
            useBackCanvas = backgroundCanvas
            ctx = useBackCanvas.getContext "2d"
            # If it is simply a background color, draw the background color
            if @background?
                ctx.fillStyle = @background
                ctx.fillRect 0, 0, useBackCanvas.width, useBackCanvas.height
            else if @backPic?
                # It is a background picture
                # Normally, we just draw the background
                # However, with large backgrounds, we must calculate which ones to draw (to avoid unnecessary drawings)
                unless @largeBackPics
                    ctx.drawImage @backPic.screen, Math.min(@trx, @w - gameWidth), Math.min(@try, @h - gameHeight), useBackCanvas.width, useBackCanvas.height, 0, 0, useBackCanvas.width, useBackCanvas.height
                else
                    v = room.view()
                    if v[0] % gameWidth is 0 and v[1] % gameHeight is 0
                       ctx.drawImage @smallCan[v[0] / gameWidth][v[1] / gameHeight], v[0], v[1]
                    else
                        flooredx = Math.floor(v[0]/gameWidth)
                        ceiledx = Math.ceil(v[0]/gameWidth)
                        flooredy = Math.floor(v[1]/gameHeight)
                        ceiledy = Math.ceil(v[1]/gameHeight)
                        ctx.drawImage @smallCan[flooredx][flooredy], flooredx * gameWidth - v[0], flooredy * gameHeight - v[1]
                        ctx.drawImage @smallCan[flooredx][ceiledy], flooredx * gameWidth - v[0], ceiledy * gameHeight - v[1]
                        ctx.drawImage @smallCan[ceiledx][flooredy], ceiledx * gameWidth - v[0], flooredy * gameHeight - v[1]
                        ctx.drawImage @smallCan[ceiledx][ceiledy], ceiledx * gameWidth - v[0], ceiledy * gameHeight - v[1]
            newFunct = ->
                evalArray = (fns, caller, args...) ->
                    return switch $.type(fns)
                        when "function" then fns.apply caller, args
                        when "array"
                            for i in fns
                                i.apply caller, args
                        else no
                # Refreshes the staticInst by redrawing them
                if @draw? and @useBackCan
                        ctx.save()
                        ctx.translate @x + @width/2, @y + @height/2
                        ctx.rotate @imgAngle * Math.PI / 180
                        ctx.translate -(@x + @width/2), -(@y + @height/2)
                        ctx.translate -room.trx, -room.try
                        evalArray @draw, this, ctx
                        ctx.restore()
            for inst in @staticInst
                newFunct.call inst

            roomBar =  do ->
                v = room.view()
                x: v[0]
                y: v[1]
                width: gameWidth
                height: gameHeight
            for inst in @deactivated
                continue unless inst
                # Deactivated instances are there because they are not inside the view
                insideView = collisionRect inst.mask(), roomBar
                if insideView
                    obj = inst.constructor
                    ind = @deactivated.indexOf inst
                    @deactivated.splice ind, 1
                    if inst.sprite.useDom
                        $(".divSprite#{inst.sprite.id}:eq(#{inst.id - 1})").css "display", "block"
                    insts = Idea obj, this
                    insts.push inst
            return
    refresh: (ctx = if useDom then game_screen else game_screen.getContext('2d')) ->
        # Refreshes the room
        # First, draw the background if we are not using the background canvas
        if (not @background? or @useBackCanvas ) and not useDom
            ctx.clearRect 0, 0, room.w, room.h
        else if (@background? and not @useBackCanvas) and not useDom
            ctx.fillStyle = @background
            ctx.fillRect 0, 0, room.w, room.h
        else if @background and useDom
            $(game_screen).css "background-color", @background
        unless @useBackCanvas or useDom
            ctx.translate -@trx, -@try
            @backPic?.draw? game_screen.getContext('2d'), 0, 0
            ctx.restore()
        unless $.isEmptyObject @following
            f = @following
            if f.instance.y >= room.view()[1] + gameHeight - (f.borderY + f.instance.height) && room.view()[1] < room.h - gameHeight then room.view(0, f.speedY)
            if f.instance.y <= room.view()[1] + f.borderY && room.view()[1] > 0 then room.view(0, -f.speedY)
            if f.instance.x >= room.view()[0] + gameWidth - (f.borderX + f.instance.width) && room.view()[0] < room.w - gameWidth then room.view(f.speedX, 0)
            if f.instance.x <= room.view()[0] + f.borderX && room.view()[0] > 0 then room.view(-f.speedX, 0)
        for alarm in alarms
            if alarm?.value > 0 and --alarm.value is 0
                    alarm.value = -1
                    alarm.trigger()
        unless useDom
            ctx.save()
            ctx.translate -@trx, -@try
        inst?.events?() for inst in i for i in room.allInstances
        unless useDom
            ctx.restore()
        inst.destroy(off) for inst in @toDestroy
        @toDestroy = []
        if @roomToGoTo
            roomGoto @roomToGoTo, no
            @roomToGoTo = off
        return
    view: (mx = 0, my = 0, relative = yes) ->
        [viewX, viewY] = [@trx, @try]
        if relative
            @trx += mx
            @try += my
        else
            @trx = mx
            @try = my
        unless (relative and mx is 0 and my is 0) or (not relative and mx is viewX and my is viewY)
            @refreshBackground?()
        [@trx, @try]
    follow: (instance, borderX, borderY, speedX, speedY) ->
        @following.instance = instance
        @following.borderX = borderX
        @following.borderY = borderY
        @following.speedX = speedX
        @following.speedY = speedY
        return
Idea.Room = Room
Idea.roomGoto = roomGoto = (newRoom, toBuffer = settings.bufferRoomGoto, callback) ->
    if toBuffer and room?
        room.roomToGoTo = newRoom
        return switch newRoom
            when "next" then allRooms[room.id + 1]
            when "previous" then allRooms[room.id - 1]
            else newRoom
    prevRoom = room
    if prevRoom?
        trigger inst, "roomEnd" for inst in i for i in prevRoom.allInstances
        $("div[class^='divSprite']").remove()
        unless prevRoom.persistent
            prevRoom.allInstances = new InstanceArray()
            for i in allObjects
                prevRoom.allInstances.push []
    switch newRoom
        when "next"
            room = allRooms[room.id + 1]
        when "previous"
            room = allRooms[room.id - 1]
        else
            room = newRoom
    room.create?()
    room.refreshBackground?()
    trigger inst, "roomStart" for inst in i for i in room.allInstances
    room
Idea.getRoom = -> room
# Export Idea
window["Idea"] = Idea
