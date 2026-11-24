import { MessageSquare, Plus } from "lucide-react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { NavLink, useNavigate, useParams } from "react-router";
import { ChatView } from "../components/ChatView";
import { ErrorBanner } from "../components/ErrorBanner";
import { buttonClass } from "../components/ui";
import { api } from "../lib/api";
import { keys } from "../lib/queryKeys";
import type { Conversation } from "../lib/types";

export function ChatPage() {
  const { id } = useParams();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const conversations = useQuery({
    queryKey: keys.conversations,
    queryFn: () => api.get<Conversation[]>("/conversations"),
  });
  const create = useMutation({
    mutationFn: () => api.post<Conversation>("/conversations"),
    onSuccess: async (conversation) => {
      await queryClient.invalidateQueries({ queryKey: keys.conversations });
      navigate(`/chat/${conversation.id}`);
    },
  });

  return (
    <div className="grid gap-6 md:grid-cols-[13rem_minmax(0,1fr)]">
      <aside className={id ? "hidden md:block" : ""}>
        <button type="button" className={`${buttonClass} w-full`} onClick={() => create.mutate()} disabled={create.isPending}>
          <Plus aria-hidden="true" />
          Neuer Chat
        </button>
        {create.isError && (
          <div className="mt-3">
            <ErrorBanner error={create.error} />
          </div>
        )}
        {conversations.isError ? (
          <div className="mt-3">
            <ErrorBanner error={conversations.error} />
          </div>
        ) : (
          <ul aria-label="Chats" className="mt-4 space-y-0.5">
            {conversations.data?.map((conversation) => (
              <li key={conversation.id}>
                <NavLink
                  to={`/chat/${conversation.id}`}
                  className={({ isActive }) =>
                    `flex items-center gap-2 rounded-lg px-2.5 py-2 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-accent/40 ${
                      isActive ? "bg-accent-soft font-medium text-accent" : "text-text/80 hover:bg-surface hover:text-text"
                    }`
                  }
                >
                  <MessageSquare aria-hidden="true" className="size-4 shrink-0 opacity-70" strokeWidth={1.75} />
                  <span className="truncate">{conversation.title ?? "Neuer Chat"}</span>
                </NavLink>
              </li>
            ))}
          </ul>
        )}
      </aside>
      {id ? (
        <ChatView key={id} conversationId={id} />
      ) : (
        <p className="text-muted md:pt-2">Wähle links einen Chat oder starte einen neuen.</p>
      )}
    </div>
  );
}
