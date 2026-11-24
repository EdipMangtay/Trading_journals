#!/usr/bin/env python3
"""Deterministically generate the dependency-free Xcode project."""
from pathlib import Path
import hashlib
ROOT = Path(__file__).resolve().parent.parent
objects = {}
def uid(key): return hashlib.sha1(key.encode()).hexdigest()[:24].upper()
def add(key, body):
    i = uid(key); objects[i] = body; return i
def arr(values): return '(' + ', '.join(values) + ')'
def q(value): return '"' + str(value).replace('\\', '\\\\').replace('"', '\\"') + '"'
app_files = sorted((ROOT / 'LiquidityEdge').rglob('*.swift'))
test_files = sorted((ROOT / 'Tests').glob('*.swift'))
def file(path):
    rel = str(path.relative_to(ROOT)); return add('file:' + rel, f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {q(rel)}; sourceTree = SOURCE_ROOT;')
def build_phase(key, paths):
    builds = [add('build:' + str(p.relative_to(ROOT)), f'isa = PBXBuildFile; fileRef = {file(p)};') for p in paths]
    return add(key, f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = {arr(builds)}; runOnlyForDeploymentPostprocessing = 0;')
app_sources = build_phase('appSources', app_files); test_sources = build_phase('testSources', test_files)
assets = add('assets', 'isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = LiquidityEdge/Resources/Assets.xcassets; sourceTree = SOURCE_ROOT;')
assets_build = add('assetsBuild', f'isa = PBXBuildFile; fileRef = {assets};')
resources = add('resources', f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({assets_build}); runOnlyForDeploymentPostprocessing = 0;')
frameworks = add('frameworks', 'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = (); runOnlyForDeploymentPostprocessing = 0;')
app_product = add('appProduct', 'isa = PBXFileReference; explicitFileType = wrapper.application; path = "Liquidity Edge.app"; sourceTree = BUILT_PRODUCTS_DIR;')
test_product = add('testProduct', 'isa = PBXFileReference; explicitFileType = wrapper.cfbundle; path = LiquidityEdgeTests.xctest; sourceTree = BUILT_PRODUCTS_DIR;')
products = add('products', f'isa = PBXGroup; children = ({app_product}, {test_product}); name = Products; sourceTree = "<group>";')
app_groups = []
for folder in ['Models','Views','ViewModels','Services','Components','Charts','Utilities','Extensions','Resources']:
    children = [uid('file:' + str(p.relative_to(ROOT))) for p in app_files if p.parent.name == folder]
    if folder == 'Resources': children.append(assets)
    app_groups.append(add('group:' + folder, f'isa = PBXGroup; children = {arr(children)}; name = {folder}; sourceTree = "<group>";'))
app_group = add('appGroup', f'isa = PBXGroup; children = {arr([uid("file:LiquidityEdge/LiquidityEdgeApp.swift")] + app_groups)}; name = LiquidityEdge; sourceTree = "<group>";')
test_group = add('testGroup', f'isa = PBXGroup; children = {arr([uid("file:" + str(p.relative_to(ROOT))) for p in test_files])}; name = Tests; sourceTree = "<group>";')
root_group = add('rootGroup', f'isa = PBXGroup; children = ({app_group}, {test_group}, {products}); sourceTree = "<group>";')
def configs(key, common):
    ids = []
    for name in ['Debug', 'Release']:
        settings = dict(common)
        settings.update({'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if name == 'Debug' else '-O', 'DEBUG_INFORMATION_FORMAT': 'dwarf' if name == 'Debug' else 'dwarf-with-dsym'})
        if name == 'Debug': settings['ENABLE_TESTABILITY'] = 'YES'; settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
        ids.append(add(key + name, 'isa = XCBuildConfiguration; buildSettings = {' + ' '.join(f'{k} = {q(v)};' for k,v in settings.items()) + '}; name = ' + name + ';'))
    return add(key + 'List', f'isa = XCConfigurationList; buildConfigurations = {arr(ids)}; defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
project_configs = configs('projectConfig', {'MACOSX_DEPLOYMENT_TARGET':'14.0','SDKROOT':'macosx','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','CLANG_ENABLE_OBJC_ARC':'YES','GCC_WARN_64_TO_32_BIT_CONVERSION':'YES','SWIFT_STRICT_CONCURRENCY':'targeted'})
app_configs = configs('appConfig', {'PRODUCT_NAME':'Liquidity Edge','PRODUCT_MODULE_NAME':'LiquidityEdge','PRODUCT_BUNDLE_IDENTIFIER':'com.liquidityedge.journal','GENERATE_INFOPLIST_FILE':'YES','INFOPLIST_KEY_CFBundleDisplayName':'LIQUIDITY EDGE','INFOPLIST_KEY_LSApplicationCategoryType':'public.app-category.finance','INFOPLIST_KEY_NSHumanReadableCopyright':'Copyright © 2026 LIQUIDITY EDGE','CURRENT_PROJECT_VERSION':'6','MARKETING_VERSION':'6.0.0','CODE_SIGN_STYLE':'Automatic','CODE_SIGN_IDENTITY':'-','ENABLE_APP_SANDBOX':'YES','ENABLE_USER_SELECTED_FILES':'readwrite','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks','COMBINE_HIDPI_IMAGES':'YES'})
test_configs = configs('testConfig', {'PRODUCT_NAME':'LiquidityEdgeTests','PRODUCT_BUNDLE_IDENTIFIER':'com.liquidityedge.journal.tests','GENERATE_INFOPLIST_FILE':'YES','TEST_HOST':'$(BUILT_PRODUCTS_DIR)/Liquidity Edge.app/Contents/MacOS/Liquidity Edge','BUNDLE_LOADER':'$(TEST_HOST)','CODE_SIGN_IDENTITY':'-','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks'})
app_target = uid('appTarget'); project_id = uid('project')
proxy = add('proxy', f'isa = PBXContainerItemProxy; containerPortal = {project_id}; proxyType = 1; remoteGlobalIDString = {app_target}; remoteInfo = LiquidityEdge;')
dependency = add('dependency', f'isa = PBXTargetDependency; target = {app_target}; targetProxy = {proxy};')
add('appTarget', f'isa = PBXNativeTarget; buildConfigurationList = {app_configs}; buildPhases = ({app_sources}, {frameworks}, {resources}); buildRules = (); dependencies = (); name = LiquidityEdge; productName = "Liquidity Edge"; productReference = {app_product}; productType = "com.apple.product-type.application";')
test_target = add('testTarget', f'isa = PBXNativeTarget; buildConfigurationList = {test_configs}; buildPhases = ({test_sources}); buildRules = (); dependencies = ({dependency}); name = LiquidityEdgeTests; productName = LiquidityEdgeTests; productReference = {test_product}; productType = "com.apple.product-type.bundle.unit-test";')
add('project', f'isa = PBXProject; attributes = {{BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; TargetAttributes = {{{app_target} = {{CreatedOnToolsVersion = 16.0;}}; {test_target} = {{CreatedOnToolsVersion = 16.0; TestTargetID = {app_target};}};}};}}; buildConfigurationList = {project_configs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, Base); mainGroup = {root_group}; productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({app_target}, {test_target});')
(ROOT / 'LiquidityEdge.xcodeproj/project.pbxproj').write_text('// !$*UTF8*$!\n{ archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n' + '\n'.join(i + ' = {' + body + '};' for i, body in sorted(objects.items())) + f'\n}}; rootObject = {project_id}; }}\n')
scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3"><BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="Liquidity Edge.app" BlueprintName="LiquidityEdge" ReferencedContainer="container:LiquidityEdge.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction><TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{test_target}" BuildableName="LiquidityEdgeTests.xctest" BlueprintName="LiquidityEdgeTests" ReferencedContainer="container:LiquidityEdge.xcodeproj"/></TestableReference></Testables></TestAction><LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="Liquidity Edge.app" BlueprintName="LiquidityEdge" ReferencedContainer="container:LiquidityEdge.xcodeproj"/></BuildableProductRunnable></LaunchAction><ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{app_target}" BuildableName="Liquidity Edge.app" BlueprintName="LiquidityEdge" ReferencedContainer="container:LiquidityEdge.xcodeproj"/></BuildableProductRunnable></ProfileAction><AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/></Scheme>'''
(ROOT / 'LiquidityEdge.xcodeproj/xcshareddata/xcschemes/LiquidityEdge.xcscheme').write_text(scheme)
print(f'Generated Xcode project: {len(app_files)} app sources, {len(test_files)} test sources')
