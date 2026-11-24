import { ArrowUp, LoaderCircle, TriangleAlert, Wrench, type LucideIcon } from "lucide-react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { Link } from "react-router";
import { api } from "../lib/api";
import {
  applyChatEvent,
  startTurn,
  streamChatMessage,
  toDisplayMessages,
  type PendingTurn,
  type ToolChip,
} from "../lib/chat";
import { keys } from "../lib/queryKeys";
import type { Message } from "../lib/types";
import { ErrorBanner } from "./ErrorBanner";
import { Markdown } from "./Markdown";
import { iconButtonClass, linkClass } from "./ui";

const TOOL_ICON: Record<ToolChip["state"], LucideIcon> = { running: LoaderCircle, ok: Wrench, error: TriangleAlert };

function Bubble({ role, text, tools }: { role: "user" | "assistant"; text: string; tools: ToolChip[] }) {
  const mine = role === "user";
  return (
    <div className={`flex ${mine ? "justify-end" : "justify-start"}`}>
      <div
        data-role={role}
        className={mine ? "max-w-[85%] rounded-2xl rounded-br-md bg-accent-soft px-4 py-2.5" : "min-w-0 max-w-full px-1 py-1"}
      >
        {tools.length > 0 && (
          <div className="mb-2 flex flex-wrap gap-1.5">
            {tools.map((tool, index) => {
              const Icon = TOOL_ICON[tool.state];
              return (
                <span
                  key={`${tool.id}-${index}`}
                  className={`inline-flex items-center gap-1 rounded-full border border-border bg-surface px-2 py-0.5 font-mono text-xs ${
                    tool.state === "error" ? "text-danger" : "text-muted"
                  }`}
                >
                  <Icon
                    aria-hidden="true"
                    className={`size-3 shrink-0 ${tool.state === "running" ? "motion-safe:animate-spin" : ""}`}
                    strokeWidth={2}
                  />
                  {tool.name}
                </span>
              );
            })}
          </div>
        )}
        {text && (mine ? <p className="whitespace-pre-wrap break-words">{text}</p> : <Markdown>{text}</Markdown>)}
      </div>
    </div>
  );
}

export function ChatView({ conversationId }: { conversationId: string }) {
  const queryClient = useQueryClient();
  const messages = useQuery({
    queryKey: keys.messages(conversationId),
    queryFn: () => api.get<Message[]>(`/conversations/${conversationId}/messages`),
  });
  const [pending, setPending] = useState<PendingTurn | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [input, setInput] = useState("");
  const bottomRef = useRef<HTMLDivElement>(null);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const wasBusy = useRef(false);
  const display = useMemo(() => toDisplayMessages(messages.data ?? []), [messages.data]);

  useEffect(() => {
    bottomRef.current?.scrollIntoView?.({ block: "end" });
  }, [display.length, pending?.text, pending?.tools.length]);

  useEffect(() => {
    if (pending !== null) {
      wasBusy.current = true;
    } else if (wasBusy.current) {
      wasBusy.current = false;
      textareaRef.current?.focus();
    }
  }, [pending]);

  async function send() {
    const text = input.trim();
    if (!text || pending) return;
    setInput("");
    setError(null);
    let turn = startTurn(text);
    setPending(turn);
    try {
      await streamChatMessage(conversationId, text, (event) => {
        turn = applyChatEvent(turn, event);
        setPending(turn);
      });
    } catch (err) {
      setInput(text);
      turn = { ...turn, finished: true, error: err instanceof Error ? err.message : "Unbekannter Fehler" };
    }
    // tools may have changed data, refetch everything
    await queryClient.invalidateQueries();
    setPending(null);
    setError(turn.error);
  }

  function onKeyDown(event: KeyboardEvent<HTMLTextAreaElement>) {
    if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing) {
      event.preventDefault();
      void send();
    }
  }

  return (
    <div className="flex min-h-[70vh] min-w-0 flex-col">
      <Link to="/chat" className={`${linkClass} mb-3 self-start text-sm md:hidden`}>
        ← Chats
      </Link>
      <div className="flex-1 space-y-5" role="log" aria-busy={pending !== null}>
        {messages.isPending && <p className="text-muted">Lädt…</p>}
        {messages.isError && <ErrorBanner error={messages.error} />}
        {display.map((message) => (
          <Bubble
            key={message.id}
            role={message.role}
            text={message.text}
            tools={message.tools.map((name, index) => ({ id: `${message.id}-${index}`, name, state: "ok" }))}
          />
        ))}
        {pending && (
          <>
            <Bubble role="user" text={pending.userText} tools={[]} />
            <Bubble role="assistant" text={pending.text || (pending.tools.length > 0 ? "" : "…")} tools={pending.tools} />
          </>
        )}
        <div ref={bottomRef} />
      </div>
      {error && (
        <div className="mt-4">
          <ErrorBanner error={new Error(error)} />
        </div>
      )}
      <form
        onSubmit={(event) => {
          event.preventDefault();
          void send();
        }}
        className="sticky bottom-[calc(4rem+env(safe-area-inset-bottom))] mt-4 bg-bg pb-3 pt-2 md:bottom-0 md:pb-6"
      >
        <div className="flex items-end gap-2 rounded-2xl border border-border bg-surface p-2 pl-3 transition-colors focus-within:border-accent/60 focus-within:ring-2 focus-within:ring-accent/20">
          <textarea
            ref={textareaRef}
            aria-label="Nachricht"
            rows={2}
            value={input}
            disabled={pending !== null}
            onChange={(event) => setInput(event.target.value)}
            onKeyDown={onKeyDown}
            placeholder="Frag mich etwas… (Enter sendet, Shift+Enter neue Zeile)"
            className="min-w-0 flex-1 resize-none bg-transparent py-1.5 text-base text-text placeholder:text-muted focus:outline-none disabled:opacity-60 sm:text-sm"
          />
          <button
            type="submit"
            aria-label="Senden"
            title="Senden"
            className={`${iconButtonClass} bg-accent text-on-accent hover:bg-accent/90 hover:text-on-accent disabled:bg-muted/30 disabled:text-muted disabled:opacity-100`}
            disabled={pending !== null || !input.trim()}
          >
            <ArrowUp aria-hidden="true" strokeWidth={2.25} />
          </button>
        </div>
      </form>
    </div>
  );
}
