#!/usr/bin/env python3.13
"""Compile real adapters against current generated native API; no device/stack work."""
import argparse,hashlib,json,os,shutil,subprocess
from pathlib import Path

SDK=Path(__file__).resolve().parents[2]
WORK=SDK/'.buildlog/bfa7-finalize'


def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--generated',type=Path,default=WORK/'generated-preview')
    args=parser.parse_args();generated=args.generated.resolve()
    output=WORK/'adapter-qualification';output.mkdir(exist_ok=True)
    manifest=json.loads((SDK/'native/rgb_l1/source-manifest.json').read_text())
    jars=[]
    for pin in manifest['build']['kotlinJars']:
        name=pin['name']+'-'+pin['version']+'.jar'
        choices=[WORK/'build-jars'/name,SDK/'.buildlog/bfa7-native/build-jars'/name]
        path=next((p for p in choices if p.is_file()),None)
        assert path and path.stat().st_size==pin['sizeBytes'] and digest(path)==pin['sha256'],name
        jars.append(path)
    classpath=os.pathsep.join(map(str,jars))
    java=Path('/opt/homebrew/opt/openjdk@17/bin/java')
    base=[str(java),'-Xmx1024m','-cp',classpath,'org.jetbrains.kotlin.cli.jvm.K2JVMCompiler','-no-stdlib','-no-reflect','-jvm-target','17']
    log=output/'compiled-adapters.log'
    env=dict(os.environ,DEVELOPER_DIR='/Applications/Xcode.app/Contents/Developer')
    def run(command):
        with log.open('a') as out:subprocess.run(list(map(str,command)),cwd=SDK,env=env,stdout=out,stderr=subprocess.STDOUT,check=True)
    log.write_text('Native API shape compilation; no actual native library execution is claimed.\n')
    native_classes=output/'native-kotlin';native_classes.mkdir(exist_ok=True)
    run(base+['-classpath',classpath,'-d',native_classes,generated/'kotlin/com/utexo/rgb_lib.kt'])
    android=Path(os.environ.get('ANDROID_HOME','/Users/hardik/Library/Android/sdk'))/'platforms/android-37.0/android.jar'
    json_candidates=list((Path.home()/'.gradle/caches/modules-2/files-2.1/org.json/json/20240303').rglob('*.jar'))
    assert android.is_file() and len(json_candidates)==1
    adapter_classpath=os.pathsep.join([str(json_candidates[0]),str(android),str(native_classes),classpath])
    adapter_classes=output/'adapter-kotlin';adapter_classes.mkdir(exist_ok=True)
    names=['RgbLibSessionStore','RgbLibDtos','RgbLibOperationPolicy','RgbLibRevocationPolicy','RgbLibExistingOpenPolicy','RgbLibProfileReader','RgbLibNetworkPolicy',
           'RgbLibSessionAddress','RlnStorageClaim','RlnStorageDirectoryPolicy']
    adapter_sources=[SDK/'android/src/main/kotlin/com/utexo/rgb_sdk_flutter'/(name+'.kt') for name in names]
    native_tests=[SDK/'test/native'/(name+'.kt') for name in ['RgbLibRuntimeCapabilityChecks','RgbLibOperationPolicyChecks']]
    run(base+['-classpath',adapter_classpath,'-d',adapter_classes]+adapter_sources+native_tests)
    runtime_classpath=os.pathsep.join([str(adapter_classes),adapter_classpath])
    for name in ['RgbLibRuntimeCapabilityChecksKt','RgbLibOperationPolicyChecksKt']:
        run([java,'-cp',runtime_classpath,'com.utexo.rgb_sdk_flutter.'+name])
    headers=output/'swift-headers';headers.mkdir(exist_ok=True)
    shutil.copyfile(generated/'swift/rgb_libFFI.h',headers/'rgb_libFFI.h')
    (headers/'module.modulemap').write_text('module rgb_libFFI { header "rgb_libFFI.h" export * }\n')
    swift_names=['RgbLibSwiftHelper','RgbLibDtos','RgbLibOperationPolicy','RgbLibRevocationPolicy','RgbLibExistingOpenPolicy','RgbLibProfileReader','RgbLibNetworkPolicy',
                 'RgbLibSessionAddress','RgbLibStorageDirectoryPolicy','RlnStorageClaim','RlnStorageDirectoryPolicy']
    swift_sources=[SDK/'ios/Classes'/(name+'.swift') for name in swift_names]
    triples=[('arm64-apple-ios16.0','iphoneos'),('arm64-apple-ios16.0-simulator','iphonesimulator'),
             ('x86_64-apple-ios16.0-simulator','iphonesimulator')]
    for triple,sdk in triples:
        sysroot=subprocess.check_output(['xcrun','--sdk',sdk,'--show-sdk-path'],env=env,text=True).strip()
        modules=output/'swift-modules'/triple;modules.mkdir(parents=True,exist_ok=True)
        common=['xcrun','swiftc','-target',triple,'-sdk',sysroot,'-I',headers,'-module-cache-path',output/'swift-cache']
        run(common+['-emit-module','-parse-as-library','-module-name','RGBLib','-o',modules/'RGBLib.swiftmodule',generated/'swift/rgb_lib.swift'])
        run(common+['-typecheck','-I',modules]+swift_sources)
    proof={'passed':True,'scope':'generated API/real platform adapter shape compilation + JVM archive capability/error policy execution',
           'deviceOrStackActions':False,'nativeLibraryExecutionClaimed':False,
           'kotlinVersion':manifest['build']['kotlinVersion'],'javaVersion':17,'swiftTargets':[t[0] for t in triples],
           'generatedFiles':{str(p.relative_to(generated)):digest(p) for p in generated.rglob('*')if p.is_file()},
           'adapterFiles':{str(p.relative_to(SDK)):digest(p)for p in adapter_sources+swift_sources},'logSha256':digest(log)}
    (output/'PROOF.json').write_text(json.dumps(proof,indent=2)+'\n')
    print(json.dumps({key:value for key,value in proof.items() if key not in {'generatedFiles','adapterFiles'}},indent=2))


if __name__=='__main__':main()
