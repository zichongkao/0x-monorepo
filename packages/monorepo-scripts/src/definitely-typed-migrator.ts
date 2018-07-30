import { execAsync } from 'async-child-process';
import * as fs from 'fs';
import 'isomorphic-fetch';
import * as _ from 'lodash';
import * as mkdirp from 'mkdirp';
import * as path from 'path';
import * as rimraf from 'rimraf';

import { configs } from './utils/configs';
import { utils } from './utils/utils';

const getVersionStringWithoutPatchNumber = (version: string): string => {
    const [major, minor] = version.split('.');
    const versionWithoutPatch = `${major}.${minor}`;
    return versionWithoutPatch;
};

(async () => {
    const packageName = process.env.PKG;
    if (_.isUndefined(packageName)) {
        throw new Error('Please specify the package name with a PKG env variable');
    }
    const DT_FOLDER = '../DefinitelyTyped';
    const ENTRY_POINT_FILE_NAME = 'index.d.ts';

    utils.log('Checkout master branch');
    await execAsync('git checkout master', { cwd: DT_FOLDER });
    utils.log(`Create new branch new-type/${packageName}`);
    await execAsync(`git checkout -b new-type/${packageName}`, { cwd: DT_FOLDER });

    const typingsFilePath = path.join('packages', 'typescript-typings', 'types', packageName, ENTRY_POINT_FILE_NAME);
    const typings = fs.readFileSync(typingsFilePath).toString();
    const dtTypingsFolderPath = path.join(DT_FOLDER, 'types', packageName);
    utils.log(`Remove old folder if exists`);
    rimraf.sync(dtTypingsFolderPath);
    utils.log(`Create ${dtTypingsFolderPath}`);
    mkdirp.sync(dtTypingsFolderPath);
    // typings
    const dtTypingsPath = path.join(dtTypingsFolderPath, ENTRY_POINT_FILE_NAME);
    const url = `${configs.NPM_REGISTRY_URL}/${packageName}`;
    const response = await fetch(url);
    const npmRegistryJSON = await response.json();
    const version = npmRegistryJSON['dist-tags'].latest;
    let banner = '';
    banner += `// Type definitions for ${packageName} ${getVersionStringWithoutPatchNumber(version)}\n`;
    banner += `// Project: ${npmRegistryJSON.homepage}\n`;
    banner += `// Definitions by: Leonid Logvinov <https://github.com/LogvinovLeon>\n`;
    banner += `// Definitions: https://github.com/DefinitelyTyped/DefinitelyTyped\n`;
    banner += '// TypeScript Version: 2.4\n';
    banner += `\n`;
    fs.writeFileSync(dtTypingsPath, banner + typings);
    // tests
    const dtTestsFileName = `${packageName}-tests.ts`;
    const dtTestsPath = path.join(dtTypingsFolderPath, dtTestsFileName);
    const tests = `import {} from '${packageName}';\n\n// TODO`;
    fs.writeFileSync(dtTestsPath, tests);
    // tsconfig
    const dtTsConfigPath = path.join(dtTypingsFolderPath, 'tsconfig.json');
    const tsConfig = {
        compilerOptions: {
            module: 'commonjs',
            lib: ['es6'],
            noImplicitAny: true,
            noImplicitThis: true,
            strictNullChecks: true,
            strictFunctionTypes: true,
            baseUrl: '../',
            typeRoots: ['../'],
            types: [],
            noEmit: true,
            forceConsistentCasingInFileNames: true,
        },
        files: [ENTRY_POINT_FILE_NAME, dtTestsFileName],
    };
    fs.writeFileSync(dtTsConfigPath, JSON.stringify(tsConfig, null, 2) + '\n');
    // tslint
    const tsLint = '{ "extends": "dtslint/dt.json" }';
    const dtTsLintConfigPath = path.join(dtTypingsFolderPath, 'tslint.json');
    fs.writeFileSync(dtTsLintConfigPath, tsLint + '\n');

    utils.log(`Assing created files to git`);
    await execAsync(`git add ${path.join('types', packageName)}`, { cwd: DT_FOLDER });
})();
