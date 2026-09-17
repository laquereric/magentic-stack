/* Figma plugin sandbox (manifest "main"). Forwards UI Effects onto
 * the Plugin API through VvFigma. Editor.js must not live here. */
/* global figma, VvFigma */
if (typeof VvFigma === "undefined") {
  throw new Error("vv-figma.js must load before code.js in the sandbox bundle");
}

VvFigma.mount({ mode: "plugin" });

figma.showUI(__html__, { width: 360, height: 480 });

figma.ui.onmessage = function (msg) {
  if (!msg || msg.kind !== "effect" || !msg.effect) return;
  VvFigma.applyEffect(msg.effect);
};
