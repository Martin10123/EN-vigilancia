const campo =
  'w-full min-h-10 rounded-lg border border-slate-200/80 bg-white/80 px-3 text-sm text-slate-900 shadow-sm transition-all duration-300 placeholder:text-slate-400 hover:border-slate-300 focus:border-marca focus:bg-white focus:ring-2 focus:ring-marca/25 focus:outline-none disabled:cursor-not-allowed disabled:opacity-60'

export const campoClase = campo

export const primePt = {
  inputtext: { root: campo },
  textarea: { root: `${campo} min-h-20 py-2` },
  password: {
    root: 'relative block w-full',
    pcInputText: { root: `${campo} pr-12` },
    maskIcon: 'absolute top-1/2 right-3 size-5 -translate-y-1/2 cursor-pointer text-slate-500',
    unmaskIcon: 'absolute top-1/2 right-3 size-5 -translate-y-1/2 cursor-pointer text-slate-500',
  },
  select: {
    root: `${campo} flex cursor-pointer items-center justify-between gap-2 px-3 text-left`,
    label: 'min-w-0 flex-1 truncate data-[p-placeholder=true]:font-normal data-[p-placeholder=true]:text-slate-400',
    dropdown: 'grid size-8 shrink-0 place-items-center rounded-lg text-slate-500',
    dropdownIcon: 'size-4',
    clearIcon: 'size-4 text-slate-400',
    overlay:
      'z-[80] overflow-hidden rounded-2xl border border-slate-200/80 bg-white/95 shadow-2xl shadow-slate-950/20 backdrop-blur-xl',
    header: 'border-b border-slate-100 p-2',
    listContainer: 'max-h-72 overflow-auto p-1',
    list: 'flex flex-col gap-0.5',
    option:
      'cursor-pointer rounded-xl px-3 py-2.5 text-sm text-slate-800 transition-colors hover:bg-marca/10 data-[p-focused=true]:bg-marca/10 data-[p-selected=true]:bg-marca data-[p-selected=true]:text-white',
    emptyMessage: 'px-3 py-3 text-sm text-slate-500',
    pcFilterContainer: { root: 'relative block w-full' },
    pcFilterIconContainer: { root: 'pointer-events-none absolute top-1/2 left-3 z-10 -translate-y-1/2 text-slate-400' },
    filterIcon: 'size-4',
    pcFilter: {
      root: 'w-full rounded-xl border border-slate-200 bg-slate-50 py-2.5 pr-3 pl-9 text-sm outline-none focus:border-marca focus:bg-white focus:ring-2 focus:ring-marca/20',
    },
  },
  checkbox: {
    root: 'relative inline-flex size-5 shrink-0',
    input: 'peer absolute inset-0 z-10 m-0 size-5 cursor-pointer appearance-none opacity-0',
    box: 'grid size-5 place-items-center rounded-md border border-slate-300 bg-white text-white shadow-sm transition peer-focus-visible:ring-2 peer-focus-visible:ring-marca/40 peer-checked:border-marca peer-checked:bg-marca',
    icon: 'size-3.5',
  },
  datepicker: {
    root: 'relative block w-full',
    pcInputText: { root: 'pr-9' },
    inputIconContainer: 'pointer-events-auto absolute inset-y-0 right-2.5 flex items-center text-slate-500',
    inputicon: 'size-4 cursor-pointer',
    dropdownIcon: 'size-4',
    panel: 'z-[80] w-[18.5rem] rounded-2xl border border-slate-200/80 bg-white p-3 shadow-2xl shadow-slate-950/15',
    header: 'mb-2 flex items-center justify-between gap-1',
    title: 'flex items-center gap-1',
    selectMonth: 'rounded-lg px-2 py-1 text-sm font-semibold text-slate-800 capitalize hover:bg-slate-100',
    selectYear: 'rounded-lg px-2 py-1 text-sm font-semibold text-slate-800 hover:bg-slate-100',
    pcPrevButton: { root: 'inline-flex size-8 items-center justify-center rounded-lg text-slate-600 hover:bg-slate-100', icon: 'size-4' },
    pcNextButton: { root: 'inline-flex size-8 items-center justify-center rounded-lg text-slate-600 hover:bg-slate-100', icon: 'size-4' },
    dayView: 'w-full border-separate border-spacing-0.5',
    tableHeaderCell: 'p-0 font-normal',
    weekDay: 'block py-1 text-center text-[11px] font-semibold tracking-wide text-slate-400 uppercase',
    dayCell: 'p-0 text-center',
    day: 'mx-auto grid size-8 cursor-pointer place-items-center rounded-lg text-sm text-slate-800 hover:bg-marca/10',
    monthView: 'grid grid-cols-3 gap-1',
    month: 'cursor-pointer rounded-lg px-2 py-2 text-center text-sm text-slate-800 capitalize hover:bg-marca/10',
    yearView: 'grid grid-cols-2 gap-1',
    year: 'cursor-pointer rounded-lg px-2 py-2 text-center text-sm text-slate-800 hover:bg-marca/10',
    buttonbar: 'mt-2 flex items-center justify-between border-t border-slate-100 pt-2',
    pcTodayButton: { root: 'rounded-lg px-2 py-1 text-sm font-semibold text-marca hover:bg-marca/10' },
    pcClearButton: { root: 'rounded-lg px-2 py-1 text-sm font-medium text-slate-500 hover:bg-slate-100' },
    timePicker: 'flex items-center justify-center gap-4 py-1',
    hourPicker: 'flex flex-col items-center gap-1',
    minutePicker: 'flex flex-col items-center gap-1',
    hour: 'text-lg font-semibold tabular-nums text-slate-900',
    minute: 'text-lg font-semibold tabular-nums text-slate-900',
    separator: 'text-lg font-semibold text-slate-400',
    pcIncrementButton: { root: 'inline-flex size-8 items-center justify-center rounded-lg text-slate-600 hover:bg-slate-100', icon: 'size-4' },
    pcDecrementButton: { root: 'inline-flex size-8 items-center justify-center rounded-lg text-slate-600 hover:bg-slate-100', icon: 'size-4' },
  },
}

export const botonClase = {
  primario:
    'btn-shine inline-flex min-h-10 w-full items-center justify-center gap-2 rounded-lg bg-marca px-3.5 text-sm font-semibold text-white shadow-lg shadow-marca/30 transition-all duration-300 hover:brightness-110 active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-60 sm:w-auto',
  secundario:
    'inline-flex min-h-10 w-full items-center justify-center gap-2 rounded-lg bg-white px-3.5 text-sm font-semibold text-slate-800 ring-1 ring-slate-200 transition-all duration-300 hover:bg-slate-50 active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-60 sm:w-auto',
  peligro:
    'inline-flex min-h-10 w-full items-center justify-center gap-2 rounded-lg bg-rose-700 px-3.5 text-sm font-semibold text-white transition-all duration-300 hover:bg-rose-800 active:scale-[0.99] disabled:cursor-not-allowed disabled:opacity-60 sm:w-auto',
  fantasma:
    'inline-flex min-h-10 items-center justify-center gap-2 rounded-lg px-3 text-sm font-semibold text-slate-700 transition-all duration-300 hover:bg-white/70 disabled:opacity-60',
} as const
