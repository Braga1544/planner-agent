import { useQueryClient } from "@tanstack/react-query";
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import { onUnauthorized } from "./lib/api";
import { clearToken, getToken, setToken } from "./lib/token";

interface AuthState {
  token: string | null;
  login: (token: string) => void;
  logout: () => void;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient();
  const [token, setTokenState] = useState<string | null>(() => getToken());

  useEffect(
    () =>
      onUnauthorized(() => {
        queryClient.clear();
        setTokenState(null);
      }),
    [queryClient],
  );

  const login = useCallback((value: string) => {
    setToken(value);
    setTokenState(value);
  }, []);

  const logout = useCallback(() => {
    clearToken();
    queryClient.clear();
    setTokenState(null);
  }, [queryClient]);

  const value = useMemo(() => ({ token, login, logout }), [token, login, logout]);
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth muss innerhalb von AuthProvider verwendet werden");
  return context;
}
