import {weekCount} from './util.js';

describe('first test suite' ,  () => {

    it('first test', () => {

        expect(weekCount(2019)).toBe(52);
    });

    it('CI test', () => {
        expect(true).toBe(true);
        expect(true).toBe(true);
    });
});