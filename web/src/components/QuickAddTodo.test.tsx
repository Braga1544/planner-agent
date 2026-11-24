import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { render, screen } from "@testing-library/react";
import { QuickAddTodo } from "./QuickAddTodo";

function ui(day: string) {
  return (
    <QueryClientProvider client={new QueryClient()}>
      <QuickAddTodo key={day} defaultDue={day} />
    </QueryClientProvider>
  );
}

test("new day resets the due date", () => {
  const { rerender } = render(ui("2026-10-09"));
  expect(screen.getByLabelText("Fällig am")).toHaveValue("2026-10-09");
  rerender(ui("2026-10-10"));
  expect(screen.getByLabelText("Fällig am")).toHaveValue("2026-10-10");
});
