import { useChartDB } from '@/hooks/use-chartdb';
import { useConfig } from '@/hooks/use-config';
import { useDialog } from '@/hooks/use-dialog';
import { useFullScreenLoader } from '@/hooks/use-full-screen-spinner';
import { useRedoUndoStack } from '@/hooks/use-redo-undo-stack';
import { useStorage } from '@/hooks/use-storage';
import type { Diagram } from '@/lib/domain/diagram';
import { useEffect, useRef, useState } from 'react';
import { useNavigate, useParams, useSearchParams } from 'react-router-dom';

export const useDiagramLoader = () => {
    const [searchParams, setSearchParams] = useSearchParams();
    const action = searchParams.get('action');
    const pendingActionKey = `chartdb-action-${document.documentElement.dataset.dashboardUser}`;
    const { openImportDatabaseDialog, openExportSQLDialog } = useDialog();
    const [initialDiagram, setInitialDiagram] = useState<Diagram | undefined>();
    const { diagramId } = useParams<{ diagramId: string }>();
    const { config } = useConfig();
    const { loadDiagram, currentDiagram } = useChartDB();
    const { resetRedoStack, resetUndoStack } = useRedoUndoStack();
    const { showLoader, hideLoader } = useFullScreenLoader();
    const { openCreateDiagramDialog, openOpenDiagramDialog } = useDialog();
    const navigate = useNavigate();
    const { listDiagrams } = useStorage();

    const currentDiagramLoadingRef = useRef<string | undefined>(undefined);

    useEffect(() => {
        if (!config) {
            return;
        }

        if (action === 'design') {
            currentDiagramLoadingRef.current = diagramId ?? '';
            sessionStorage.removeItem(pendingActionKey);
            setSearchParams({}, { replace: true });
            openCreateDiagramDialog();
            return;
        }
        if (action === 'import' || action === 'export') {
            sessionStorage.setItem(pendingActionKey, action);
        }

        if (diagramId && currentDiagram?.id === diagramId) {
            return;
        }

        const loadDefaultDiagram = async () => {
            if (diagramId) {
                setInitialDiagram(undefined);
                showLoader();
                resetRedoStack();
                resetUndoStack();
                const diagram = await loadDiagram(diagramId);
                if (!diagram) {
                    openOpenDiagramDialog({ canClose: false });
                    hideLoader();
                    return;
                }

                setInitialDiagram(diagram);
                hideLoader();

                return;
            } else if (!diagramId && config.defaultDiagramId) {
                const diagram = await loadDiagram(config.defaultDiagramId);
                if (diagram) {
                    navigate(
                        `/diagrams/${config.defaultDiagramId}${action ? `?action=${action}` : ''}`
                    );

                    return;
                }
            }
            const diagrams = await listDiagrams();

            if (diagrams.length > 0) {
                openOpenDiagramDialog({ canClose: false });
            } else {
                openCreateDiagramDialog();
            }
        };

        if (
            currentDiagramLoadingRef.current === (diagramId ?? '') &&
            currentDiagramLoadingRef.current !== undefined
        ) {
            return;
        }
        currentDiagramLoadingRef.current = diagramId ?? '';

        loadDefaultDiagram();
    }, [
        action,
        pendingActionKey,
        setSearchParams,
        diagramId,
        openCreateDiagramDialog,
        config,
        navigate,
        listDiagrams,
        loadDiagram,
        resetRedoStack,
        resetUndoStack,
        hideLoader,
        showLoader,
        currentDiagram?.id,
        openOpenDiagramDialog,
    ]);

    useEffect(() => {
        const diagram =
            initialDiagram ??
            (currentDiagram?.id === diagramId ? currentDiagram : undefined);
        if (!diagram) {
            return;
        }
        const pendingAction = sessionStorage.getItem(pendingActionKey);
        sessionStorage.removeItem(pendingActionKey);
        if (pendingAction === 'import') {
            openImportDatabaseDialog({
                databaseType: diagram.databaseType,
                importMethods: ['ddl', 'dbml'],
                initialImportMethod: 'ddl',
            });
        } else if (pendingAction === 'export') {
            openExportSQLDialog({
                targetDatabaseType: diagram.databaseType,
            });
        } else {
            return;
        }
        setSearchParams({}, { replace: true });
    }, [
        currentDiagram,
        diagramId,
        initialDiagram,
        pendingActionKey,
        openImportDatabaseDialog,
        openExportSQLDialog,
        setSearchParams,
    ]);

    return { initialDiagram };
};
