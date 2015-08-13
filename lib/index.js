"use strict";
/*global Windows, WinJS */

var makeEmitter = require("pubit-as-promised").makeEmitter;

var app = WinJS.Application;
var activation = Windows.ApplicationModel.Activation;
var activationKind = activation.ActivationKind;

// Kinds http://msdn.microsoft.com/en-us/library/windows/apps/windows.applicationmodel.activation.activationkind
// Extra 8.1 kinds {"restrictedLaunch": 12, "appointmentsProvider": 13, "contact": 14, "lockScreenCall": 15 };
// Extra 10.0 kinds {"voiceCommand": 16, "lockScreen": 17}

var allEvents = ["splash", "load", "restore", "launch", "suspend", "resume"];
var publish = makeEmitter(exports, allEvents);
var publishers = {};

exports.registerKindPlugin = function (plugin) {
    var kindStr = plugin.kind;
    var kind = activationKind[kindStr];
    if (kind !== undefined) {
        publishers[kind] = plugin.publish;
    } else {
        throw new Error("[winningjs-lifecycle.registerKindPlugin] Unsupported kind: " + kindStr);
    }
};

exports.start = function () {
    WinJS.Binding.optimizeBindingReferences = true;

    app.addEventListener("activated", function (args) {

        function publishSplash() {
            var promise = new WinJS.Promise(function (complete) {
                publish.when("splash", args.detail.splashScreen).done(complete);
            });
            args.setPromise(promise);
        }

        function publishLoad() {
            publish.when("load", args.detail.previousExecutionState).done(publishRestore);
            args.setPromise(WinJS.UI.processAll());
        }

        function publishRestore() {
            if (args.detail.previousExecutionState === activation.ApplicationExecutionState.terminated) {
                publish.when("restore", WinJS.Application.sessionState).done(publishKind);
            } else {
                publishKind(); // Skip right to publishing the kind.
            }
        }

        function publishKind() {
            var kind = args.detail.kind;
            if (publishers[kind]) { // Supported kind plugin registered?
                publishers[kind](args);
            } else if (kind === activationKind.launch) {
                publish("launch", args.detail.arguments);
            } else {
                throw new Error("[winningjs-lifecycle.publishKind] no kind plug-in found (kind=" + kind + ")");
            }
        }

        var pes = args.detail.previousExecutionState;
        var aes = activation.ApplicationExecutionState;
        if (pes === aes.notRunning || pes === aes.terminated || pes === aes.closedByUser) {
            publishSplash();
            publishLoad();
        } else { // Here if Running or Suspended.
            publishKind(); // Publish the actual kind.
        }

    });

    app.addEventListener("checkpoint", function (args) {
        app.sessionState = {};
        var promise = new WinJS.Promise(function (complete) {
            publish.when("suspend", app.sessionState).done(complete);
        });
        args.setPromise(promise);
    });

    Windows.UI.WebUI.WebUIApplication.addEventListener("resuming", function () {
        publish("resume");
    });

    app.start();
};
