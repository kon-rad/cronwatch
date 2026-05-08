import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import { ToastView, type ToastKind } from '@/components/Toast';

export type ToastInput = {
  message: string;
  kind?: ToastKind;
  duration?: number;
  action?: { label: string; onPress: () => void };
};

type ActiveToast = ToastInput & { id: string; kind: ToastKind };

type Ctx = {
  show: (input: ToastInput) => string;
  dismiss: (id?: string) => void;
};

const ToastCtx = createContext<Ctx | null>(null);

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [active, setActive] = useState<ActiveToast | null>(null);
  const queueRef = useRef<ActiveToast[]>([]);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const showNext = useCallback(() => {
    const next = queueRef.current.shift() ?? null;
    setActive(next);
    if (next && next.duration && next.duration > 0) {
      timerRef.current = setTimeout(() => {
        setActive(null);
        showNext();
      }, next.duration);
    }
  }, []);

  const show = useCallback(
    (input: ToastInput): string => {
      const id = `t_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`;
      const toast: ActiveToast = { id, kind: input.kind ?? 'info', ...input };
      if (active) {
        queueRef.current.push(toast);
      } else {
        setActive(toast);
        if (toast.duration && toast.duration > 0) {
          timerRef.current = setTimeout(() => {
            setActive(null);
            showNext();
          }, toast.duration);
        }
      }
      return id;
    },
    [active, showNext],
  );

  const dismiss = useCallback(
    (id?: string) => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
      setActive((cur) => {
        if (!cur) return null;
        if (id && cur.id !== id) {
          queueRef.current = queueRef.current.filter((q) => q.id !== id);
          return cur;
        }
        return null;
      });
      setTimeout(() => showNext(), 0);
    },
    [showNext],
  );

  useEffect(
    () => () => {
      if (timerRef.current) clearTimeout(timerRef.current);
    },
    [],
  );

  const ctx = useMemo<Ctx>(() => ({ show, dismiss }), [show, dismiss]);

  return (
    <ToastCtx.Provider value={ctx}>
      {children}
      {active ? (
        <ToastView
          message={active.message}
          kind={active.kind}
          action={active.action}
          onDismiss={() => dismiss(active.id)}
        />
      ) : null}
    </ToastCtx.Provider>
  );
}

export function useToast(): Ctx {
  const ctx = useContext(ToastCtx);
  if (!ctx) throw new Error('useToast must be used inside <ToastProvider>');
  return ctx;
}
