import * as chai from 'chai';
import chaiAsPromised = require('chai-as-promised');

export const chaiSetup = {
    configure(): void {
        chai.config.includeStack = true;
        chai.use(chaiAsPromised);
    },
};
