export const EDITION_DATA = {
  COMPLETE: "complete",
  G18_202X: "202X",
  G18_2010: "2010",
} as const;

export function editionDataName(uiName: string): string {
  return uiName === "current" ? EDITION_DATA.COMPLETE : uiName;
}

export function editionUiLabel(dataName: string): string {
  if (dataName === "complete") return "OIML";
  return dataName;
}

export function editionShortLabel(dataName: string): string {
  if (dataName === "complete") return "OIML";
  return dataName;
}

export function sortedEditions(eds: string[] | undefined): string[] {
  const order: Record<string, number> = {
    "complete": 0, "202X": 1, "2010": 2,
    "viml-2022": 3, "viml-2013": 4, "viml-2000": 5,
    "vim-2012": 6, "vim-2007": 7, "vim-1993": 8,
  };
  return [...(eds || [])].sort((a, b) => (order[a] ?? 99) - (order[b] ?? 99));
}

export function isOimlSpecific(kind: string): boolean {
  return kind === "oiml_original" || kind === "undefined";
}
