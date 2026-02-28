const DEFAULT_KEY = Symbol("default");

export function cached<A extends PropertyKey | undefined, T>(
  fn: (arg?: A) => Promise<T>,
): (arg?: A) => Promise<T> {
  const cache = new Map<PropertyKey | typeof DEFAULT_KEY, Promise<T>>();
  return (arg?: A) => {
    const key = arg ?? DEFAULT_KEY;
    const hit = cache.get(key);
    if (hit) {
      return hit;
    }
    const promise = fn(arg);
    cache.set(key, promise);
    return promise;
  };
}
