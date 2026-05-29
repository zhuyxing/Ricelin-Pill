function create() {
    return {
        items: [],
        undoStack: [],
        redoStack: [],

        add: function (ann) {
            this.items.push(ann);
            this.undoStack.push({ kind: "add", ann: ann });
            this.redoStack = [];
            return ann;
        },

        undo: function () {
            if (this.undoStack.length === 0) return false;
            var op = this.undoStack.pop();
            if (op.kind === "add") this.items.pop();
            this.redoStack.push(op);
            return true;
        },

        redo: function () {
            if (this.redoStack.length === 0) return false;
            var op = this.redoStack.pop();
            if (op.kind === "add") this.items.push(op.ann);
            this.undoStack.push(op);
            return true;
        },

        canUndo: function () { return this.undoStack.length > 0; },
        canRedo: function () { return this.redoStack.length > 0; }
    };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { create: create };
}
