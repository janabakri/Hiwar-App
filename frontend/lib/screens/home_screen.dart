// مرجع التصميم: نسخة Flutter من speak-app-prototype(2).html؛ RTL، هاتف دافئ، بطاقات بيضاء، بنفسجي #4B3F8F، شاشات home/voice/feedback/explore/progress/profile.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/hiwar_api.dart';

const bg = Color(0xFFF6F3EF);
const paper = Colors.white;
const ink = Color(0xFF241F38);
const inkSoft = Color(0xFF635C7A);
const inkFaint = Color(0xFF948DA6);
const primary = Color(0xFF4B3F8F);
const primaryDark = Color(0xFF332A66);
const primaryTint = Color(0xFFECEAF7);
const coralTint = Color(0xFFFBE7DA);
const rust = Color(0xFFB23B3B);
const rustTint = Color(0xFFF8E7E6);
const line = Color(0xFFE6E1DA);

TextStyle ar(double size, {FontWeight weight = FontWeight.w400, Color color = ink}) => GoogleFonts.ibmPlexSansArabic(fontSize: size, fontWeight: weight, color: color);
TextStyle en(double size, {FontWeight weight = FontWeight.w400, Color color = ink}) => GoogleFonts.ibmPlexSans(fontSize: size, fontWeight: weight, color: color);
TextStyle mono(double size, {FontWeight weight = FontWeight.w500, Color color = ink}) => GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  final _api = HiwarApi();

  void _open(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeContent(onVoice: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VoiceScreen(api: _api)))),
      ExploreContent(),
      ProgressContent(),
      ProfileContent(api: _api),
    ];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFEEEAE4),
        body: SafeArea(child: pages[_index]),
        bottomNavigationBar: _BottomNav(index: _index, onTap: _open),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(color: paper, border: Border(top: BorderSide(color: line))),
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _NavItem(icon: Icons.home_outlined, label: 'الرئيسية', active: index == 0, onTap: () => onTap(0)),
      _NavItem(icon: Icons.search, label: 'استكشف', active: index == 1, onTap: () => onTap(1)),
      _NavItem(icon: Icons.bar_chart_outlined, label: 'تقدّمي', active: index == 2, onTap: () => onTap(2)),
      _NavItem(icon: Icons.person_outline, label: 'حسابي', active: index == 3, onTap: () => onTap(3)),
    ]),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  const _NavItem({required this.icon, required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 22, color: active ? primary : inkFaint), const SizedBox(height: 3), Text(label, style: ar(11, weight: FontWeight.w600, color: active ? primary : inkFaint))])));
}

class _Card extends StatelessWidget {
  final Widget child; final EdgeInsets padding; final VoidCallback? onTap;
  const _Card({required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  @override
  Widget build(BuildContext context) { final content = Container(padding: padding, decoration: BoxDecoration(color: paper, borderRadius: BorderRadius.circular(18), border: Border.all(color: line)), child: child); return onTap == null ? content : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: content); }
}

class _SectionTitle extends StatelessWidget { final String text; final String? tag; const _SectionTitle(this.text, {this.tag}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 22, bottom: 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(text, style: ar(13, weight: FontWeight.w600, color: inkSoft)), if (tag != null) Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(20)), child: Text(tag!, style: ar(11, weight: FontWeight.w600, color: primary)))])); }

class _Ring extends StatelessWidget { final String value; final String label; const _Ring({required this.value, this.label = 'التقدم'}); @override Widget build(BuildContext context) => Container(width: 64, height: 64, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: SweepGradient(colors: [primary, primary, primaryTint, primaryTint])), child: Center(child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: paper, shape: BoxShape.circle), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('', style: TextStyle(height: 0)), Text(value, style: mono(12, weight: FontWeight.w600)), Text(label, style: ar(8, color: inkFaint))])))); }

class HomeContent extends StatelessWidget {
  final VoidCallback onVoice; const HomeContent({super.key, required this.onVoice});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مساء الخير، سارة', style: ar(19, weight: FontWeight.w700)), Text('جاهزة لمحادثة اليوم؟', style: ar(12.5, color: inkFaint))]), Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7), decoration: BoxDecoration(color: coralTint, borderRadius: BorderRadius.circular(20)), child: Row(children: [const Icon(Icons.local_fire_department, color: Color(0xFFB5451A), size: 15), const SizedBox(width: 5), Text('12 يوم', style: ar(12.5, weight: FontWeight.w600, color: const Color(0xFFB5451A)))]))]),
    const SizedBox(height: 18),
    _Card(child: Row(children: [const _Ring(value: '62%'), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('B1 — متوسط', style: ar(14.5, weight: FontWeight.w700)), Text('أقرب مستوى: B2 · Upper Intermediate', style: ar(12, color: inkFaint)), const SizedBox(height: 5), Text('XP 480 / 780', style: mono(11.5, weight: FontWeight.w600, color: primary))])])),
    const SizedBox(height: 26),
    Column(children: [GestureDetector(onTap: onVoice, child: Container(width: 132, height: 132, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(-.35, -.5), colors: [Color(0xFF6459A8), primary])), child: const Icon(Icons.mic_none, size: 44, color: Colors.white))), const SizedBox(height: 16), Text('ابدأ محادثة صوتية', style: ar(15.5, weight: FontWeight.w700)), const SizedBox(height: 3), Text('تحدّث بحرية، الذكاء الاصطناعي يستمع ويرد عليك', style: ar(12, color: inkFaint))]),
    _SectionTitle('مقترح اليوم', tag: 'مبني على أدائك'),
    _Card(onTap: onVoice, child: Row(children: [Container(width: 46, height: 46, decoration: BoxDecoration(color: primaryTint, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.menu_book_outlined, color: primary)), const SizedBox(width: 14), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('التحدث في المطعم', style: ar(14, weight: FontWeight.w700)), Text('Ordering food at a restaurant', style: en(12.5, color: inkFaint))]), const Spacer(), Text('‹', style: ar(28, color: inkFaint))])),
    const _SectionTitle('أخطاء تحتاج مراجعة'),
    SizedBox(height: 78, child: ListView(scrollDirection: Axis.horizontal, children: const [_MistakeChip(wrong: 'I have went there', correct: 'I have gone there', category: 'الأزمنة — Present Perfect'), SizedBox(width: 10), _MistakeChip(wrong: 'since three years', correct: 'for three years', category: 'since / for'), SizedBox(width: 10), _MistakeChip(wrong: 'think / think', correct: '/θɪŋk/', category: 'نطق حرف th')])),
  ]);
}

class _MistakeChip extends StatelessWidget { final String wrong, correct, category; const _MistakeChip({required this.wrong, required this.correct, required this.category}); @override Widget build(BuildContext context) => Container(width: 158, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: rustTint, border: Border.all(color: const Color(0xFFEAD3CC)), borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(wrong, style: en(12.5, weight: FontWeight.w600, color: rust).copyWith(decoration: TextDecoration.lineThrough)), Text(correct, style: en(12.5, weight: FontWeight.w600, color: primaryDark)), const Spacer(), Text(category, style: ar(10.5, color: inkFaint))])); }

class VoiceScreen extends StatefulWidget { final HiwarApi api; const VoiceScreen({super.key, required this.api}); @override State<VoiceScreen> createState() => _VoiceScreenState(); }
class _VoiceScreenState extends State<VoiceScreen> { String status = 'اضغط للبدء بالحديث'; bool active = false; Timer? timer; int seconds = 0; @override void dispose(){timer?.cancel(); super.dispose();} void toggle(){ if(!active){setState((){active=true; status='أنصت إليك...'; seconds=0;}); timer=Timer.periodic(const Duration(seconds:1),(_){setState(()=>seconds++);});} else {timer?.cancel(); setState(()=>status='لحظة، يفكر بالرد...'); Future.delayed(const Duration(milliseconds:1100),(){if(!mounted)return; setState(()=>status='يتحدث الآن...'); Future.delayed(const Duration(milliseconds:2200),(){if(mounted)setState(()=>status='اضغط للمتابعة');});});} } @override Widget build(BuildContext context)=>Scaffold(backgroundColor:bg, appBar: AppBar(backgroundColor:bg,elevation:0, leading:IconButton(icon:const Icon(Icons.close,color:ink),onPressed:()=>Navigator.pop(context)), title:Text('B1 · Ordering food at a restaurant',style:ar(12,color:inkFaint))), body:Column(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Column(children:[const SizedBox(height:60),Text(status,style:ar(13.5,weight:FontWeight.w600,color:inkSoft)),const SizedBox(height:22),Container(width:190,height:190,decoration:const BoxDecoration(shape:BoxShape.circle,gradient:RadialGradient(center:Alignment(-.3,-.45),colors:[Color(0xFF6459A8),primary])),child:Center(child:active?Row(mainAxisSize:MainAxisSize.min,children:List.generate(6,(i)=>Container(width:5,height:28+(i%3)*10,margin:const EdgeInsets.symmetric(horizontal:2),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(4))))):const Icon(Icons.mic_none,size:40,color:Colors.white))),const SizedBox(height:22),Text('${(seconds~/60).toString().padLeft(2,'0')}:${(seconds%60).toString().padLeft(2,'0')}',style:mono(13,color:inkFaint))]), Padding(padding:const EdgeInsets.only(bottom:32),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Column(children:[IconButton(onPressed:toggle,icon:const Icon(Icons.mic_none),iconSize:26,style:IconButton.styleFrom(backgroundColor:paper,side:const BorderSide(color:line),fixedSize:const Size(64,64))),Text('اضغط وتحدث',style:ar(11.5,color:inkFaint))]),const SizedBox(width:34),Column(children:[IconButton(onPressed:()=>Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>FeedbackScreen(api:widget.api))),icon:const Icon(Icons.close),color:Colors.white,iconSize:26,style:IconButton.styleFrom(backgroundColor:rust,fixedSize:const Size(64,64))),Text('إنهاء',style:ar(11.5,color:inkFaint))])]))]); }

class FeedbackScreen extends StatelessWidget { final HiwarApi api; const FeedbackScreen({super.key,required this.api}); @override Widget build(BuildContext context)=>Scaffold(backgroundColor:bg,appBar:AppBar(backgroundColor:bg,elevation:0,title:Text('مراجعة المحادثة',style:ar(16,weight:FontWeight.w700))),body:ListView(padding:const EdgeInsets.fromLTRB(20,8,20,30),children:[Center(child:Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),decoration:BoxDecoration(color:primaryTint,borderRadius:BorderRadius.circular(20)),child:Text('✓ انتهت المحادثة',style:ar(12,weight:FontWeight.w700,color:primaryDark)))),Center(child:Padding(padding:const EdgeInsets.only(top:12),child:Text('أداء جيد اليوم',style:ar(18,weight:FontWeight.w700)))),Center(child:Text('4 دقائق · Ordering food at a restaurant',style:ar(12.5,color:inkFaint))),const _SectionTitle('أهم الأخطاء'),const _ReviewCard(number:'1',wrong:'I want to ordering a pizza',correct:'I want to order a pizza',explain:'بعد want to نستخدم الفعل بصورته الأساسية (order) وليس صورة ing.'),const _ReviewCard(number:'2',wrong:'since three years',correct:'for three years',explain:'نستخدم for مع مدة زمنية، وsince مع نقطة بداية محددة.'),const _ReviewCard(number:'3',wrong:'I think — نُطقت /sɪŋk/',correct:'النطق الصحيح: /θɪŋk/',explain:'ضعي طرف اللسان بين الأسنان مع خروج الهواء.'),const _SectionTitle('كلمات جديدة استخدمتِها'),Wrap(spacing:8,runSpacing:8,children:const [_WordChip('recommend — يوصي'),_WordChip('medium-rare — نصف نضج'),_WordChip('to go — للتغليف')]),const SizedBox(height:22),FilledButton.icon(onPressed:()=>Navigator.pop(context),icon:const Icon(Icons.bolt),label:Text('العودة للمحادثة',style:ar(14,weight:FontWeight.w700)),style:FilledButton.styleFrom(backgroundColor:primary,padding:const EdgeInsets.all(16))) ]); }
class _ReviewCard extends StatelessWidget {final String number,wrong,correct,explain;const _ReviewCard({required this.number,required this.wrong,required this.correct,required this.explain});@override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:12),child:_Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[CircleAvatar(radius:12,backgroundColor:rustTint,child:Text(number,style:mono(11,color:rust))),const SizedBox(width:10),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('"$wrong"',style:en(13.5,color:rust).copyWith(decoration:TextDecoration.lineThrough)),Text('✓ $correct',style:en(13.5,weight:FontWeight.w600,color:primaryDark))]))]),const Divider(height:20,color:line),Text(explain,style:ar(12.5,color:inkSoft).copyWith(height:1.7))])));}
class _WordChip extends StatelessWidget {final String text;const _WordChip(this.text);@override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:13,vertical:8),decoration:BoxDecoration(color:paper,border:Border.all(color:line),borderRadius:BorderRadius.circular(20)),child:Text(text,style:ar(12.5)));}

class ExploreContent extends StatelessWidget { @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(20,12,20,28),children:[const _SectionTitle('استكشف'),Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(gradient:const LinearGradient(colors:[primaryDark,primary]),borderRadius:BorderRadius.all(Radius.circular(18))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('✦ اقتراح ذكي لكِ',style:ar(11,weight:FontWeight.w700,color:Colors.white)),const SizedBox(height:8),Text('بناءً على محادثاتك الأخيرة، ركّزي هالأسبوع على Present Perfect ونطق حرف th — قبل ما ننتقل لمهارة جديدة.',style:ar(13,color:Colors.white).copyWith(height:1.6))])),const SizedBox(height:16),GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,mainAxisSpacing:12,crossAxisSpacing:12,childAspectRatio:1.05,children:const [_Skill(title:'التحدث',english:'Speaking',value:70,color:primaryTint),_Skill(title:'الاستماع',english:'Listening',value:55,color:Color(0xFFE7EEF7)),_Skill(title:'القراءة',english:'Reading',value:48,color:Color(0xFFF7EEDB)),_Skill(title:'الكتابة',english:'Writing',value:40,color:Color(0xFFF6E6EB)),_Skill(title:'القواعد',english:'Grammar',value:58,color:Color(0xFFE9E7F2)),_Skill(title:'المفردات',english:'Vocabulary',value:65,color:rustTint)])]); }
}
class _Skill extends StatelessWidget {final String title,english;final int value;final Color color;const _Skill({required this.title,required this.english,required this.value,required this.color});@override Widget build(BuildContext context)=>_Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:38,height:38,decoration:BoxDecoration(color:color,borderRadius:BorderRadius.circular(11)),child:const Icon(Icons.auto_awesome_outlined,size:19,color:primary)),const SizedBox(height:9),Text(title,style:ar(13.5,weight:FontWeight.w700)),Text(english,style:en(11,color:inkFaint)),const Spacer(),ClipRRect(borderRadius:BorderRadius.circular(5),child:LinearProgressIndicator(value:value/100,minHeight:5,backgroundColor:line,color:primary)),const SizedBox(height:5),Text('$value%',style:mono(10.5,color:inkFaint))]));}

class ProgressContent extends StatelessWidget { @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(20,12,20,28),children:[const _SectionTitle('تقدّمي'),_Card(child:Row(children:[_Ring(value:'480',label:'XP'),SizedBox(width:16),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('B1 — متوسط',style:ar(14.5,weight:FontWeight.w700)),Text('12 يوم متتالي · 34 محادثة',style:ar(12,color:inkFaint))])])),const _SectionTitle('سجل الأخطاء المتكررة'),const _Card(child:ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(radius:12,backgroundColor:rustTint,child:Text('×7',style:TextStyle(color:rust,fontSize:11))),title:Text('Present Perfect vs Past Simple'),subtitle:Text('أكثر خطأ تكرر معك هذا الشهر')),),const SizedBox(height:12),const _Card(child:ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(radius:12,backgroundColor:rustTint,child:Text('×4',style:TextStyle(color:rust,fontSize:11))),title:Text('نطق حرف th'),subtitle:Text('تحسّن ملحوظ عن الشهر الماضي')))]); }

class ProfileContent extends StatefulWidget { final HiwarApi api; const ProfileContent({super.key,required this.api}); @override State<ProfileContent> createState()=>_ProfileContentState(); }
class _ProfileContentState extends State<ProfileContent> { HiwarStats? stats; String? error; bool loading=true; final controller=TextEditingController(); @override void initState(){super.initState();_load();} Future<void> _load() async {setState(()=>loading=true); final id=await widget.api.getUserId(); controller.text=id; try{final result=await widget.api.getStats(id); if(mounted)setState((){stats=result;error=null;loading=false;});}catch(e){if(mounted)setState((){error=e.toString().replaceFirst('Exception: ','');loading=false;});}} Future<void> _connect() async {await widget.api.saveUserId(controller.text);_load();} @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.fromLTRB(20,12,20,28),children:[Row(children:[Container(width:58,height:58,decoration:BoxDecoration(color:primaryTint,borderRadius:BorderRadius.circular(20)),child:const Icon(Icons.person_outline,color:primary,size:28)),const SizedBox(width:12),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('حسابي',style:ar(11,color:inkFaint)),Text(stats?.userName??'معلوماتي في Hiwar',style:ar(19,weight:FontWeight.w700)),Text(controller.text,style:mono(10,color:inkFaint))])]),const SizedBox(height:14),_Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('معرّف المستخدم',style:ar(12,weight:FontWeight.w700,color:inkSoft)),const SizedBox(height:8),Row(children:[Expanded(child:TextField(controller:controller,textDirection:TextDirection.ltr,style:mono(11),decoration:InputDecoration(hintText:'أدخلي user_id من Hiwar',hintStyle:ar(11,color:inkFaint),isDense:true,border:OutlineInputBorder(borderRadius:BorderRadius.circular(11),borderSide:const BorderSide(color:line))))),const SizedBox(width:8),FilledButton(onPressed:_connect,style:FilledButton.styleFrom(backgroundColor:primary),child:Text('تحديث',style:ar(12,weight:FontWeight.w700,color:Colors.white)))])])),if(loading)const Padding(padding:EdgeInsets.only(top:14),child:_Card(child:Text('جارٍ تحميل معلوماتك...'))),if(!loading&&error!=null)Padding(padding:const EdgeInsets.only(top:14),child:_Card(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('تعذر جلب المعلومات',style:ar(13,weight:FontWeight.w700,color:rust)),const SizedBox(height:6),Text(error!,style:ar(11,color:inkSoft)),const SizedBox(height:10),FilledButton(onPressed:_load,style:FilledButton.styleFrom(backgroundColor:primary),child:Text('إعادة المحاولة',style:ar(12,color:Colors.white))),const SizedBox(height:5),Text('API: ${widget.api.baseUrl}',style:mono(9,color:inkFaint))]))),if(!loading&&error==null&&stats!=null) ...[_Card(child:Row(children:[_Ring(value:'${stats!.levelScore}%',label:'المستوى'),const SizedBox(width:16),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(stats!.level,style:ar(14.5,weight:FontWeight.w700)),Text('تقدمك الحالي في التعلم',style:ar(12,color:inkFaint)),Text('${stats!.levelScore} نقطة مستوى',style:mono(11,color:primary))])])),const SizedBox(height:12),GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,mainAxisSpacing:10,crossAxisSpacing:10,childAspectRatio:1.5,children:[_AccountStat(value:'${stats!.totalSessions}',label:'محادثة'),_AccountStat(value:'${stats!.streakDays}',label:'يوم متتالي'),_AccountStat(value:'${stats!.totalErrors}',label:'خطأ مسجل'),_AccountStat(value:'${stats!.masteryRate}%',label:'نسبة الإتقان')])]]); }
}
class _AccountStat extends StatelessWidget {final String value,label;const _AccountStat({required this.value,required this.label});@override Widget build(BuildContext context)=>_Card(child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Text(value,style:mono(17,weight:FontWeight.w600,color:primary)),Text(label,style:ar(11,color:inkFaint))]));}
