// Global Vitest setup for the Stimulus controller specs. jsdom provides most of what the
// controllers touch (classList, dataset, replaceChildren, createElement/createTextNode);
// anything it doesn't implement gets a double here.

// The leg switcher observes the nav and its own bar so it re-measures the sticky offsets when
// either changes height. The specs drive re-measuring through scroll and resize events, so an
// inert double is enough.
globalThis.ResizeObserver = class {
  observe() {}
  unobserve() {}
  disconnect() {}
};
