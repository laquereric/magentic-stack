// Overlay-supplied routes for the mind-pod FRONT.
//
// front-base merges these into its own proxy maps when FRONT_OVERRIDE points
// at this directory. The route -> CPCP method mapping lives here, in the
// product overlay, so front-base never has to know what a note is.
//
// Shape matches front-base's maps: PUSH entries carry { rpc, push }, PULL
// entries carry { rpc, keys } where keys are query params lifted into params.
export const PULL = {
  "GET /notes/list": { rpc: "note.list", keys: [] }
};

export const PUSH = {
  "POST /notes": { rpc: "note.create", push: true }
};
