import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";
import { createBrowserRouter, RouterProvider } from "react-router";
import { AuthProvider, useAuth } from "./auth";
import { ApiError } from "./lib/api";
import { LoginPage } from "./pages/LoginPage";
import { routes } from "./routes";

function createQueryClient() {
  return new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 15_000,
        // don't retry 4xx, otherwise once
        retry: (failureCount, error) =>
          !(error instanceof ApiError && error.status >= 400 && error.status < 500) && failureCount < 1,
      },
    },
  });
}

function Root() {
  const { token } = useAuth();
  const [router] = useState(() => createBrowserRouter(routes));
  return token ? <RouterProvider router={router} /> : <LoginPage />;
}

export function App() {
  const [queryClient] = useState(createQueryClient);
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <Root />
      </AuthProvider>
    </QueryClientProvider>
  );
}
