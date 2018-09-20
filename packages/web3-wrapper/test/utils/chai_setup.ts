import { BigNumber } from '@0xproject/utils';
import * as chai from 'chai';
import chaiAsPromised = require('chai-as-promised');
import ChaiBigNumber = require('chai-bignumber');

export const chaiSetup = {
    configure(): void {
        chai.config.includeStack = true;
        chai.use(ChaiBigNumber(BigNumber));
        chai.use(chaiAsPromised);
    },
};
