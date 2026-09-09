// GENERATED from gems/shapes-application/contracts/mind-pod/linkml/pod-note.yaml. Do not hand-edit.
//
// generator:    gen-typescript (linkml 1.11.1)
// source-sha256: 85faee409000e9842f8812e47cfef23762903f6a83beec6b027e10642d7edba9
//
// Regenerate with tooling/linkml/generate_shapes.py. The shape container
// owns this file; editing it here makes the artifact stop tracing to its
// source, which check_shape_artifacts.py fails on.

export type NoteId = string;


/**
 * A note as BACK records it. Closed on purpose: a caller that could add a property this shape does not name would be writing state nothing downstream knows how to read.
 */
export interface Note {
    /** The row id. Carried in the subject IRI, not beside it. */
    id: string,
    /** Present and non-empty; the model validates presence too. */
    title: string,
    /** Optional. Absent emits no triple rather than an empty literal. */
    body?: string,
    /** Server-stamped, ISO 8601. BACK sets this; a caller does not. */
    created_at: string,
}
