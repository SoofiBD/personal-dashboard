import React from 'react';
import type { RouteObject } from 'react-router-dom';
import { createBrowserRouter } from 'react-router-dom';

const routes: RouteObject[] = [
    ...['', 'diagrams/:diagramId'].map((path) => ({
        path,
        async lazy() {
            const { EditorPage } =
                await import('./pages/editor-page/editor-page');

            return {
                element: <EditorPage />,
            };
        },
    })),
    {
        path: '*',
        async lazy() {
            const { NotFoundPage } =
                await import('./pages/not-found-page/not-found-page');
            return {
                element: <NotFoundPage />,
            };
        },
    },
];

export const router = createBrowserRouter(routes, {
    basename: '/database-editor',
});
