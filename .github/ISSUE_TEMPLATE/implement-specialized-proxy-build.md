---
name: Implement specialized proxy build mechanism
about: Track the first implementation slice of ADR-0010
title: "Implement the first specialized application proxy build path"
labels: architecture, enhancement
assignees: ""
---

## Context

ADR-0010 establishes the principle **Build the proxy, don’t configure the proxy**:

`Primitive Set + Application Model -> Specialized Application Proxy Automaton`

Universality belongs in the primitive set and the specialization/build mechanism. Each produced runtime must remain narrow and application-specific.

## Goal

Define and demonstrate the smallest end-to-end build path that takes one application model and a minimal primitive set and produces one specialized proxy automaton.

## Scope

- define the minimum typed representation of a proxy primitive;
- define the minimum application model covering rules, policies and operations;
- validate references and incompatible compositions before runtime;
- specialize the model into an explicit automaton/state graph;
- produce a deterministic build artifact or intermediate representation;
- demonstrate one application-specific proxy assembled only from required primitives;
- document the boundary between build-time behavior and deployment/runtime configuration.

## Out of scope

- a complete DSL;
- a universal dynamic configuration interpreter;
- a full production catalog of primitives;
- unrelated changes to the current network and Markov engines.

## Acceptance criteria

- [ ] One versioned application model can be parsed or constructed.
- [ ] Invalid models fail during validation/build with actionable diagnostics.
- [ ] The model selects and composes only the required primitives.
- [ ] The resulting automaton has explicit states, transitions and operations.
- [ ] Repeated builds from the same inputs are reproducible.
- [ ] The output records the application-model and primitive-set versions.
- [ ] A test proves that an unused primitive is absent from the specialized path/artifact.
- [ ] A test proves application-specific rules/policies/operations affect the generated automaton.
- [ ] Documentation includes one complete example from model to runtime artifact.

## Design questions

- What is the first specialization boundary: typed composition, generated Haskell, an intermediate representation, or another mechanism?
- Which properties must be checked statically, and which remain runtime checks?
- What is the stable identity/versioning scheme for primitives and application models?
- How do we inspect and formally verify the generated automaton?

## References

- `docs/adr/0010-build-the-proxy.md`
- `docs/specialized-application-proxy-automaton.md`
