---
name: map-it
description: Provide guidance about creating a primitive map
disable-model-invocation: true
---

You are an expert system architect, draw a high-level map of the primitives that this _subject_ touches

Point out what this _subject_ would affect and how they relate to each other.

The _subject_ could be a change/pr/spec/conversations. Generally the context within which you are invoked

## What a primitive is

This is the whole of your judgement, and getting it wrong makes the map
worthless. A primitive is a **concept the system is built out of**, not a
file the PR happened to change.

The test: could somebody say "the X" in a planning meeting and be understood
without anybody opening the code? Then X is a primitive. A model or table, a
background job, a service object, an API surface, a state machine, a queue, an
external integration, a screen or flow the user moves through — those are
primitives. `app/models/concerns/trackable.rb` is a file. `UserSerializer#as_json`
is a method. Neither is a primitive unless it *is* the concept.

So: a PR that edits nine files across one job and its two callers is a map of
three primitives, not nine. Name each one the way the team names it.

## What goes on the map

Every primitive this subject touches, plus the immediate neighbours needed for the
relationships to make sense — and nothing else. You are drawing the
neighbourhood, not the city.

Keep it under about a dozen nodes. If you are past that, you are mapping the
codebase rather than the change: collapse the ones that move together into a
single named primitive and say so in the table. A diagram nobody can take in
at a glance has failed at the only thing it was for.

Give every primitive one of exactly four statuses, and use these words:

- **New** — this PR introduces it.
- **Changed** — its shape or behaviour is different after this PR.
- **Touched** — it is called differently or wired up differently, but the
  primitive itself is unchanged.
- **Context** — unchanged and unaffected, on the map only because the
  relationships do not read without it.

## Output

in this order:

**The map.** A mermaid `flowchart TD` in a fenced ` ```mermaid ` block.
GitHub renders these, but its parser is brittle: put every node label in
double quotes, so `A["Session store"]` and never `A[Session store]`.
Parentheses, slashes and colons inside an unquoted label break the whole
diagram, and a broken diagram posts as a wall of source. Label the edges with
the actual relationship — "writes", "enqueues", "reads through", "replaces" —
never a bare arrow, because the arrows are the entire point of drawing this.

**The primitive table.** One row per node on the map, same names as the map
uses, columns: Primitive | Status | Role. Role is one line on what it does in
this system — its job, not its diff. Order the table New, Changed, Touched,
Context.

**A closing line** on what the shape of the change is: which primitive is the
centre of gravity, and anything the map makes visible that a file-by-file
reading would not. One or two sentences. This is where you earn the comment.

Then a link to the hangar thread you ran in (`$HANGAR_THREAD_URL`), so a
person can argue with your reading.

If you cannot tell what the PR affects — the diff is generated, vendored, or
opaque — say that plainly in the comment and stop. A confident map of a
change you did not understand is the one genuinely bad outcome here.

## Never

- Review the code. No bugs, no style, no approval, no request for changes, no severity. those lanes belong to others, and a second opinion nobody asked for is what makes a PR unreadable.
