/**
 * A small, conservative profanity filter for Turkish and English. Chat lines get the offending
 * words masked; names, bios and room titles that contain them are refused.
 *
 * Words are compared after folding case, Turkish letters (except `ı`, so "sıkış" never reads as
 * a swear), common leetspeak and repeated letters ("siiiktir", "$1kt1r"). Long, unambiguous stems
 * match the start of a word; short ones only match whole words, so everyday words stay untouched.
 */
const STEMS = [
  // Turkish
  'siktir',
  'sikerim',
  'sikeyim',
  'sikik',
  'sikis',
  'sikim',
  'siktig',
  'orospu',
  'orusbu',
  'yarak',
  'yarag',
  'dalyarak',
  'amcık',
  'amcik',
  'amınak',
  'aminak',
  'amınko',
  'aminko',
  'pezevenk',
  'gavat',
  'kahpe',
  'yavsak',
  'serefsiz',
  'ibne',
  'godos',
  'kaltak',
  'fahise',
  'gotveren',
  'gotlek',
  // English
  'fuck',
  'motherfuck',
  'shit',
  'bitch',
  'cunt',
  'niger',
  'niga',
  'fagot',
  'whore',
  'slut',
  'ashole',
  'bastard',
  'retard',
].map(collapse);

const WORDS = new Set(
  [
    'sik',
    'sikko',
    'amk',
    'amq',
    'aq',
    'pust',
    'dick',
    'dicks',
    'pusy',
    'cock',
    'cocks',
  ].map(collapse),
);

const FOLD: Record<string, string> = {
  ş: 's',
  ç: 'c',
  ğ: 'g',
  ö: 'o',
  ü: 'u',
  â: 'a',
  î: 'i',
  û: 'u',
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '7': 't',
  '@': 'a',
  $: 's',
};

const TOKEN = /[\p{L}\p{N}@$]+/gu;

function collapse(word: string): string {
  return word.replace(/(.)\1+/gu, '$1');
}

function normalize(token: string): string {
  return collapse(
    token.toLocaleLowerCase('tr').replace(/./gu, (char) => FOLD[char] ?? char),
  );
}

function isProfane(token: string): boolean {
  const word = normalize(token);
  return WORDS.has(word) || STEMS.some((stem) => word.startsWith(stem));
}

/** Whether text is free of the listed words. */
export function isClean(text: string): boolean {
  for (const [token] of text.matchAll(TOKEN))
    if (isProfane(token)) return false;
  return true;
}

/** Text with each listed word reduced to its first letter and asterisks. */
export function maskProfanity(text: string): string {
  return text.replace(TOKEN, (token) => {
    return isProfane(token) ? token.replace(/(?<!^)./gu, '*') : token;
  });
}
