import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api } from "./api";
import type { Item, ItemCreate, ItemUpdate } from "./types";

// just invalidate everything, single user anyway
export function useInvalidateAll(): () => Promise<void> {
  const queryClient = useQueryClient();
  return () => queryClient.invalidateQueries();
}

export function useCreateItem() {
  const invalidate = useInvalidateAll();
  return useMutation({ mutationFn: (data: ItemCreate) => api.post<Item>("/items", data), onSuccess: invalidate });
}

export function useUpdateItem() {
  const invalidate = useInvalidateAll();
  return useMutation({
    mutationFn: ({ id, changes }: { id: string; changes: ItemUpdate }) => api.patch<Item>(`/items/${id}`, changes),
    onSuccess: invalidate,
  });
}

export function useArchiveItem() {
  const invalidate = useInvalidateAll();
  return useMutation({ mutationFn: (id: string) => api.delete<Item>(`/items/${id}`), onSuccess: invalidate });
}
