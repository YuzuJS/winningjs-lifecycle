"use strict"

pes = 0
kind = 999
fun = ->
global.WinJS =
    UI: {}
    Promise: sinon.spy((cb) ->
        cb(fun)
    )
    Application: {}
    Binding: {}

global.Windows = 
    ApplicationModel: Activation: 
        ApplicationExecutionState: {
            notRunning: 0,
            running: 1,
            suspended: 2,
            terminated: 3,
            closedByUser: 4
        }
        ActivationKind: {"foo": 999, "launch", 0}
    UI: WebUI: WebUIApplication: {}

winningjs = require("../lib")

describe "winningjs-lifecycle", ->

    describe "registerKindPlugin", ->
        it "should be exported", ->
            winningjs.should.ownProperty("registerKindPlugin")

        describe "and when called with a valid kind", ->
            it "should add it to publishers", ->
                expect(winningjs.registerKindPlugin.bind(winningjs,({kind:"foo", publish: ->}))).not.to.throw(Error);

        describe "but when called with an invalid kind", ->
            it "should thow an error", ->
                expect(winningjs.registerKindPlugin.bind(winningjs,({kind:"bar", publish: ->}))).to.throw(Error);

    describe "start", ->
        it "should be exported", ->
            winningjs.should.ownProperty("start")

        describe "and when called...", ->
            beforeEach ->
                @processAll = sinon.spy()
                @addEventListener = sinon.spy((event, cb) ->
                    eventObject = if event is "activated" then {
                            setPromise: sinon.spy()
                            detail:
                                previousExecutionState: pes
                                kind: kind
                                arguments: "arguments"
                                splashScreen: "splashScreen"
                        } else if event is "checkpoint" then {
                            setPromise: sinon.spy()
                            }
                    cb(eventObject) 
                )
                @splashHandler = sinon.spy()
                @suspendHandler = sinon.spy()
                @loadHandler = sinon.spy()
                @restoreHandler = sinon.spy()
                @launchHandler = sinon.spy()
                @webUIaddEventListener = sinon.spy()
                global.WinJS.UI.processAll = @processAll
                global.WinJS.Application.addEventListener = @addEventListener
                global.WinJS.Application.start = ->
                global.Windows.UI.WebUI.WebUIApplication.addEventListener = @webUIaddEventListener
                global.WinJS.Binding.optimizeBindingReferences = false
                winningjs.registerKindPlugin({kind:"foo", publish: -> @pubHandler})
                winningjs.on("suspend", @suspendHandler)
                winningjs.on("splash", @splashHandler)
                winningjs.on("load", @loadHandler)
                winningjs.on("restore", @restoreHandler)
                winningjs.on("launch", @launchHandler)
            afterEach ->
                winningjs.off("suspend", @suspendHandler)
                winningjs.off("splash", @splashHandler)
                winningjs.off("load", @loadHandler)
                winningjs.off("restore", @restoreHandler)
                winningjs.off("launch", @launchHandler)

            it "should set WinJS.Binding.optimizeBindingReferences to true", ->
                pes = global.Windows.ApplicationModel.Activation.ApplicationExecutionState.running
                winningjs.start()
                WinJS.Binding.optimizeBindingReferences.should.be.true

            describe "and call app.addEventListener with `activated` and when `previousExecutionState` is `notRunning`...", ->
                beforeEach ->
                    pes = global.Windows.ApplicationModel.Activation.ApplicationExecutionState.notRunning
                    winningjs.start()

                it "should publish a `splash` event", ->
                    @splashHandler.should.be.calledWith("splashScreen")

                it "should publish a `load` event", ->
                    @loadHandler.should.be.calledWith(pes)
                
                it "should NOT publish a `restore` event", (next) ->
                    setTimeout( =>
                        @restoreHandler.should.not.be.called
                        next()
                    , 20);

            describe "and call app.addEventListener with `activated` and when `previousExecutionState` is `running`...", ->
                beforeEach ->
                    pes = global.Windows.ApplicationModel.Activation.ApplicationExecutionState.running
                    winningjs.start()

                it "should NOT publish `splash`", ->
                    @splashHandler.should.not.be.called
                it "should NOT publish `load`", ->
                    @loadHandler.should.not.be.called
                it "should NOT publish `restore`", (next) ->
                    setTimeout( =>
                        @restoreHandler.should.not.be.called
                        next()
                    , 20);

            describe "and call app.addEventListener with `activated` and when `previousExecutionState` is `terminated`...", ->
                beforeEach ->
                    pes = global.Windows.ApplicationModel.Activation.ApplicationExecutionState.terminated
                    winningjs.start()
                it "should publish `splash`", ->
                    @splashHandler.should.be.called
                it "should publish `load`", ->
                    @loadHandler.should.be.called
                it "should publish `restore`", (next) ->
                    setTimeout( =>
                        @restoreHandler.should.be.called
                        next()
                    , 20);


            describe "and call app.addEventListener with `activated`", ->
                beforeEach ->
                    pes = global.Windows.ApplicationModel.Activation.ApplicationExecutionState.running
                it "and when `kind` is `launch`, should publish `launch`", ->
                    kind = global.Windows.ApplicationModel.Activation.ActivationKind.launch
                    winningjs.start()
                    @launchHandler.should.be.calledWith("arguments")

                it "and when `kind` anything other than `launch`, should NOT publish `launch`", ->
                    kind = global.Windows.ApplicationModel.Activation.ActivationKind.foo
                    winningjs.start()
                    @launchHandler.should.not.be.called

            describe "should call app.addEventListener with `checkpoint`", ->
                it "which should publish a `suspend` event", ->
                    winningjs.start()
                    @suspendHandler.should.be.called

    describe "app.start", ->
        beforeEach ->
            @appStart = sinon.spy()
            global.WinJS.Application.start = @appStart
            winningjs.start()
        it "should be called", ->
            @appStart.should.be.called
