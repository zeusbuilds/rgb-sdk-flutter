@main struct SessionAddressChecks {
 static func main() {
  for mode in ["signing","watch-only"] {
   let foreignProfileAddress="foreign-profile-address"
   var calls=0
   let native = { calls+=1; return "native-\(mode)-\(calls)" }
   let firstSession=RgbLibSessionAddress()
   let first=firstSession.get(reuse:true,rotate:false,derive:native)
   precondition(first != foreignProfileAddress && calls==1)
   precondition(firstSession.get(reuse:true,rotate:false,derive:native)==first && calls==1)
   precondition(firstSession.get(reuse:true,rotate:true,derive:native) != first && calls==2)
   let reopened=RgbLibSessionAddress()
   precondition(reopened.get(reuse:true,rotate:false,derive:native) != foreignProfileAddress && calls==3)
   _=reopened.get(reuse:false,rotate:false,derive:native);precondition(calls==4)
  }
  print("Swift session-owned address cache derives initially/reopens for signing and watch-only")
 }
}
