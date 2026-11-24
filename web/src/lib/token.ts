const KEY = "planner-agent-token";
// fallback when localStorage is unavailable (private mode)
let memoryToken: string | null = null;

export function getToken(): string | null {
  try {
    return localStorage.getItem(KEY);
  } catch {
    return memoryToken;
  }
}

export function setToken(token: string): void {
  try {
    localStorage.setItem(KEY, token);
  } catch {
    memoryToken = token;
  }
}

export function clearToken(): void {
  memoryToken = null;
  try {
    localStorage.removeItem(KEY);
  } catch {
    // ignore
  }
}
