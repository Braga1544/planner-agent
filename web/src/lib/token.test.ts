import { clearToken, getToken, setToken } from "./token";

test("stores, reads and clears the token", () => {
  expect(getToken()).toBeNull();
  setToken("abc");
  expect(getToken()).toBe("abc");
  expect(localStorage.getItem("planner-agent-token")).toBe("abc");
  clearToken();
  expect(getToken()).toBeNull();
});

test("works without localStorage", () => {
  const spy = vi.spyOn(Storage.prototype, "setItem").mockImplementation(() => {
    throw new Error("privater Modus");
  });
  const getSpy = vi.spyOn(Storage.prototype, "getItem").mockImplementation(() => {
    throw new Error("privater Modus");
  });
  setToken("xyz");
  expect(getToken()).toBe("xyz");
  spy.mockRestore();
  getSpy.mockRestore();
  clearToken();
});

test("returns null when localStorage is cleared", () => {
  setToken("abc");
  expect(getToken()).toBe("abc");
  localStorage.clear();
  expect(getToken()).toBeNull();
});
