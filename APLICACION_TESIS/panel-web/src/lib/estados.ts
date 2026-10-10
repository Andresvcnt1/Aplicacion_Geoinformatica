// Fuente única de verdad de los estados en el panel web.
// Debe coincidir con Incidencia.Estado y Incidencia.TRANSICIONES del backend (el backend es quien valida).

export type EstadoValor =
  | 'recibido'
  | 'en_revision'
  | 'en_proceso'
  | 'subsanado'
  | 'no_viable'
  | 'cerrado';

export interface EstadoMeta {
  value: EstadoValor;
  label: string;
  color: string;  // hex: puntos de leyenda, marcadores del mapa
  badge: string;  // clases Tailwind del badge (claro/oscuro)
  activo: string; // clases Tailwind del botón seleccionado
}

export const ESTADOS: EstadoMeta[] = [
  {
    value: 'recibido', label: 'Recibido', color: '#ef4444',
    badge: 'bg-red-50 text-red-700 border-red-200 dark:bg-red-950 dark:text-red-300 dark:border-red-900',
    activo: 'bg-red-500 text-white border-red-500',
  },
  {
    value: 'en_revision', label: 'En revisión', color: '#f59e0b',
    badge: 'bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950 dark:text-amber-300 dark:border-amber-900',
    activo: 'bg-amber-500 text-white border-amber-500',
  },
  {
    value: 'en_proceso', label: 'En proceso', color: '#f97316',
    badge: 'bg-orange-50 text-orange-700 border-orange-200 dark:bg-orange-950 dark:text-orange-300 dark:border-orange-900',
    activo: 'bg-orange-500 text-white border-orange-500',
  },
  {
    value: 'subsanado', label: 'Subsanado', color: '#22c55e',
    badge: 'bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950 dark:text-emerald-300 dark:border-emerald-900',
    activo: 'bg-emerald-500 text-white border-emerald-500',
  },
  {
    value: 'no_viable', label: 'No viable', color: '#64748b',
    badge: 'bg-slate-100 text-slate-700 border-slate-300 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-600',
    activo: 'bg-slate-500 text-white border-slate-500',
  },
  {
    value: 'cerrado', label: 'Cerrado', color: '#0f766e',
    badge: 'bg-teal-50 text-teal-700 border-teal-200 dark:bg-teal-950 dark:text-teal-300 dark:border-teal-900',
    activo: 'bg-teal-600 text-white border-teal-600',
  },
];

export const TRANSICIONES: Record<EstadoValor, EstadoValor[]> = {
  recibido: ['en_revision', 'no_viable'],
  en_revision: ['en_proceso', 'no_viable'],
  en_proceso: ['subsanado', 'no_viable'],
  subsanado: ['cerrado', 'en_proceso'],
  no_viable: ['cerrado'],
  cerrado: [],
};

// Estados que obligan a escribir una observación
export const EXIGEN_OBSERVACION: EstadoValor[] = ['no_viable'];

const BADGE_DEFECTO =
  'bg-slate-50 text-slate-700 border-slate-200 dark:bg-slate-800 dark:text-slate-300 dark:border-slate-700';

export const metaEstado = (valor: string): EstadoMeta | undefined =>
  ESTADOS.find((e) => e.value === valor);

export const etiquetaEstado = (valor: string): string => metaEstado(valor)?.label ?? valor;
export const colorEstado = (valor: string): string => metaEstado(valor)?.color ?? '#6b7280';
export const claseBadge = (valor: string): string => metaEstado(valor)?.badge ?? BADGE_DEFECTO;

export const siguientesEstados = (valor: string): EstadoMeta[] => {
  const permitidos = TRANSICIONES[valor as EstadoValor] ?? [];
  return ESTADOS.filter((e) => permitidos.includes(e.value));
};