import { isClean, maskProfanity } from './profanity.js';

describe('profanity filter', () => {
  it('masks Turkish and English swears, including leetspeak and stretched letters', () => {
    expect(maskProfanity('siktir git')).toBe('s***** git');
    expect(maskProfanity('SİİİKTİR')).toBe('S*******');
    expect(maskProfanity('$1kt1r ya')).toBe('$***** ya');
    expect(maskProfanity('what the fuck')).toBe('what the f***');
    expect(maskProfanity('amk bu ne')).toBe('a** bu ne');
    expect(maskProfanity('aminakoyim')).toBe('a*********');
  });

  it('leaves everyday words alone', () => {
    for (const text of [
      'Sıkıştım biraz, kahve molası',
      'fizik çalışıyorum',
      'şikayet etmeyelim',
      'Amina ile çalışıyoruz',
      'got it, thanks',
      'Scunthorpe',
      'ambulans, amaç, ama',
    ]) {
      expect(maskProfanity(text)).toBe(text);
    }
  });

  it('refuses names that contain a swear', () => {
    expect(isClean('orospucocugu')).toBe(false);
    expect(isClean('Kütüphane Ekibi')).toBe(true);
  });
});
