import type { RouteObject } from "react-router";
import { Layout } from "./components/Layout";
import { AreaPage } from "./pages/AreaPage";
import { CalendarPage } from "./pages/CalendarPage";
import { ChatPage } from "./pages/ChatPage";
import { ProjectPage } from "./pages/ProjectPage";
import { SearchPage } from "./pages/SearchPage";
import { SettingsPage } from "./pages/SettingsPage";
import { TodayPage } from "./pages/TodayPage";

export const routes: RouteObject[] = [
  {
    path: "/",
    element: <Layout />,
    children: [
      { index: true, element: <TodayPage /> },
      { path: "einstellungen", element: <SettingsPage /> },
      { path: "chat", element: <ChatPage /> },
      { path: "chat/:id", element: <ChatPage /> },
      { path: "kalender", element: <CalendarPage /> },
      { path: "bereiche/:area", element: <AreaPage /> },
      { path: "projekte/:id", element: <ProjectPage /> },
      { path: "suche", element: <SearchPage /> },
      { path: "*", element: <p className="text-muted">Seite nicht gefunden.</p> },
    ],
  },
];
