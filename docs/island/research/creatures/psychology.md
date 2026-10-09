# Creatures on the control board: what the psychology and UX research says

Prepared 2026-10-08 for the Fovea Island decision: should each agent session on the control board be a
small dynamic creature (cute, visibly busy) instead of a static icon?

Method: abstracts and metadata from OpenAlex, Crossref, Europe PMC and Semantic Scholar; claims checked
against citing papers' descriptions where publishers hide abstracts; practitioner sources read directly
(NN/g, Apple HIG via its DocC JSON, W3C WCAG source, calmtech.com, The Verge, Wikipedia). No PDFs were
downloaded. Where a claim rests on secondary description, it says so. Evidence strength is rated
Strong / Moderate / Weak-or-contested.

---

## 0. Bottom line

**The research supports part of the instinct.**
- Motion makes simple shapes read as living agents, automatically (Heider & Simmel, replicated 75 years
  later).
- Humanized and cute agents get more warmth, trust and forgiveness (Waytz 2014; de Visser 2016; Lv 2021).
- Showing work raises its perceived value (Buell & Norton 2011).
- A waiting display that shows something alive reduces uncertainty (Maister 1985; Myers 1985; NN/g).

**It also predicts specific failures here.** The Island is peripheral, always on, multi-agent and used at
work:
1. Continuous motion near the edge of vision costs attention, then habituates into "banner blindness"
   (Burke 2005).
2. When everything moves, the thing that should catch the eye no longer does. Motion *onset* captures
   attention; ongoing motion does not (Abrams & Christ 2003). A target moving among moving distractors is a
   hard search (Royden et al. 2001).
3. Cute, humanized framing does three things wrong:
   - It lowers competence expectations (Zebrowitz; Lv).
   - It softens failures in ways that can hide them.
   - It backfires when the user is already frustrated (Crolic 2022).
4. Faces and eyes capture attention on their own (Langton 2008; Driver 1999).
5. Sad or needy creatures produce avoidance and guilt (Fish'n'Steps; De Freitas 2025).
6. The novelty fades within about two weeks (Kanda 2004).

**The evidence favors a narrow version: the creature is the state glyph.**
- It replaces the icon's badge or glyph; it is not added decoration.
- It is still or near-still while working, and moves once when its state changes.
- It looks at you only when it needs you.
- It never suffers.
- It can be turned off.

The broad version is a row of pets that bounce all the time. The research predicts users will love that
for a week and then mute it.

In one line: **busy where the user is looking (the open board), calm where they are not (the closed
notch).**

**Fit with Fovea's current spec.**
- `docs/island/AGENT_PANEL.md` says: "No decoration: no mascots, carousels or sounds."
- The Oct 6 round-three research (`docs/island/FEEDBACK_2026-10-06.md`) concluded "Illustration only where
  it carries state" and "Only running moves; color only for action."
- Mascots in Notchi and coucou were judged "charming but cost a third of the panel and add nothing to
  read."
- A creature design fits these rules only if it replaces the state glyph or badge and keeps the motion and
  color rules. Anything broader needs an explicit amendment.

---

## 1. Animacy from motion

**Evidence**
- **Heider & Simmel (1944).** *American Journal of Psychology*, doi:10.2307/1416950.
  - Observers watched a short film of two triangles and a circle moving around a box.
  - Almost all of them described the shapes as persons with intentions and emotions.
  - Describing the film in purely physical terms proved hard.
- **Ratajska, Brown & Chabris.** Preprint 2019, doi:10.31234/osf.io/2d9xj.
  - 32 new animated-shape videos again produced spontaneous social attributions (N = 66).
  - People varied in how many attributions they made, and so did the videos.
- **Scholl & Tremoulet (2000).** *Trends in Cognitive Sciences*, doi:10.1016/S1364-6613(00)01506-0.
  - Review: perceived causality and animacy behave like perception (fast, automatic, driven by specific
    cues), not like slow inference.
  - Abstract not retrieved; this is the review's well-known thesis.
- **Tremoulet & Feldman (2000).** *Perception*, doi:10.1068/p3101.
  - A single moving dot looks alive when its speed and direction change together.
  - Animacy ratings rose with the size of the speed and direction change.
  - Ratings also rose when the object's long axis was aligned with its direction of motion.
- **Gao, McCarthy & Scholl (2010), "The wolfpack effect."** *Psychological Science*,
  doi:10.1177/0956797610388814.
  - Darts or "discs with eyes" moving at random, but always facing a target, look like they are pursuing it.
  - This impaired interactive tasks, and people steered their own disc away from the shapes.

**Strength: Strong.**

**Implications for the board**
- **Very little makes a creature look alive.** A 16 pt blob that starts on its own, or changes speed or
  direction, will be read as an agent. The risk is too much life, not too little.
- **Keep the working loop non-directional.** Self-propelled changes of direction are the strongest animacy
  cue. Save them for moments that should be noticed. The working loop should be periodic and symmetric
  (breathing-like), with no wandering and no changes of direction.
- **Default orientation is toward its own work.** What a creature faces reads as what it attends to. A row
  of creatures oriented toward the cursor reads as being watched or chased. In the wolfpack study, shapes
  oriented like that disrupted the task.
- **Every motion will be read as a message.** The percept is automatic, so the user cannot un-see a mood
  because they know it is a status icon. Only ship motions whose message you accept ("I'm stuck", "I'm
  done", "I need you").

---

## 2. Anthropomorphism: trust, forgiveness and over-trust

**Evidence**
- **Epley, Waytz & Cacioppo (2007).** *Psychological Review*, doi:10.1037/0033-295X.114.4.864.
  People anthropomorphize more in three conditions:
  - when human-centred knowledge is accessible;
  - when they want to explain and predict an agent's behavior (effectance motivation);
  - when they lack social connection.
- **Waytz, Heafner & Epley (2014).** *Journal of Experimental Social Psychology*,
  doi:10.1016/j.jesp.2014.01.005.
  - In a driving simulator, an autonomous car with a name, a gender and a voice was trusted more than one
    with identical capability.
  - Trust rose on self-report, behavioral and physiological measures. The physiological measure was a
    smaller heart-rate and startle response when an accident happened.
  - Anthropomorphism also changed how blame for the accident was assigned.
  - The publisher hides the abstract; these details come from citing papers.
- **de Visser et al. (2016).** *Journal of Experimental Psychology: Applied*, doi:10.1037/xap0000092.
  - Advice from a computer, an avatar or a human got gradually worse.
  - Anthropomorphic agents showed more "trust resilience": trust broke down less.
  - The effect grew with uncertainty.
  - Human-like trust-repair behavior largely erased the differences between agents.
- **Crolic, Thomaz, Hadi & Stephen (2022).** *Journal of Marketing*, doi:10.1177/00222429211045687.
  - Data: real chat logs from a telecom company plus four experiments.
  - For customers who arrived angry, humanized chatbots lowered satisfaction, firm evaluation and purchase
    intent.
  - The mechanism was inflated expectations of the bot's efficacy that then went unmet.
  - There was no harm for customers who were not angry.
- **Nass & Moon (2000).** *Journal of Social Issues*, doi:10.1111/0022-4537.00153. People mindlessly
  apply social rules to computers given minimal cues: politeness, reciprocity, stereotypes.
- **Cohn et al. (2024).** CHI EA, doi:10.1145/3613905.3650818, n = 2,165.
  - Speech plus text, and a first-person "I", increased anthropomorphism.
  - They also increased perceived accuracy of identical information. The "I" effect appeared in only one
    context.
- **Bansal et al. (2021).** CHI, doi:10.1145/3411764.3445717. AI explanations made people more likely to
  accept the AI's recommendation, whether or not it was correct.
- **Parasuraman & Riley (1997).** *Human Factors*, doi:10.1518/001872097778543886.
  - Over-reliance (misuse) produces monitoring failures.
  - How salient automation state indicators are affects monitoring.
  - False alarms produce disuse.
- **The ELIZA effect.**
  - Weizenbaum (1966), *CACM*, doi:10.1145/365153.365168: a keyword-matching script that people treated
    as understanding them.
  - Abercrombie et al. (2023), EMNLP, doi:10.18653/v1/2023.emnlp-main.290: design choices drive
    personification, and personification drives over-reliance.
- **NN/g (Gibbons, Mugunthan & Nielsen, 2023)**, "The 4 Degrees of Anthropomorphism of Generative AI".
  Users anthropomorphize AI partly for a functional reason: they assume it will perform better.

**Strength: Moderate** for anthropomorphism increasing trust and forgiveness; it depends on context and
reverses with anger. **Strong** for over-reliance risks in automation.

**Implications**
- **Expect more trust and forgiveness.** That helps with small stumbles. It hurts code review: users may
  read diffs less carefully.
- **Add honesty cues the creature cannot fake.**
  - If an agent has emitted nothing for N minutes, the creature visibly rests (stale).
  - "Done" must never look like "verified".
- **Drop the persona in failures and high-stakes asks.** This covers the Failed state and Allow/Deny for a
  destructive command. Show them plainly, with no apologetic face. Crolic predicts a humanized face amplifies
  anger at a moment of frustration.
- **Stay nonverbal.** No speech bubbles and no first-person "I": Cohn found that voice and "I" raise
  perceived accuracy. Amber Case's principle "Machines shouldn't act like humans" says the same.
- **Fill the gap with facts.** Effectance motivation predicts that users anthropomorphize most when a long,
  opaque run is hard to predict. One honest line of current activity on hover (the spec allows it) stops
  them inventing a story about the creature's mood.

---

## 3. Cuteness

**Evidence**
- **Baby schema.**
  - Lorenz (1943) proposed the *Kindchenschema*.
  - Glocker et al. (2009), *Ethology*, doi:10.1111/j.1439-0310.2008.01603.x, manipulated infant faces
    parametrically.
  - Faces with more baby schema (round face, high forehead, big eyes) were rated cuter and raised the
    motivation to give care.
- **Cuteness and carefulness.**
  - Sherman, Haidt & Coan (2009), *Emotion*, doi:10.1037/a0014904: very cute images improved fine-motor
    performance in the game "Operation".
  - Nittono et al. (2012), *PLoS ONE*, doi:10.1371/journal.pone.0046362, three results:
    - fine-motor performance improved 44% after cute images, against 12% after less cute ones;
    - visual search improved 16% against 1%;
    - attention narrowed: global precedence was reduced.
- **Limits.**
  - Ziv & Fox (2022), *Frontiers in Psychology*, doi:10.3389/fpsyg.2021.800543. Preregistered, n = 98:
    no effect on computerized reaction-time tasks.
  - Fox & Ziv (2022), *PeerJ*, doi:10.7717/peerj.14439. Preregistered, n = 164: no difference between
    puppy and adult-dog images.
  - Nenkov & Scott (2014), *Journal of Consumer Research*, doi:10.1086/676581. "Whimsical" cuteness
    (playful rather than baby schema) primes fun and increases indulgent choices. That is the opposite of
    carefulness.
- **Sherman & Haidt (2011).** *Emotion Review*, doi:10.1177/1754073911402396.
  - Cuteness mainly triggers social engagement and play.
  - Cute things are "hyper-mentalized" and readily anthropomorphized, which amplifies everything in §2.
- **Lv et al. (2021).** *Annals of Tourism Research*, doi:10.1016/j.annals.2020.103114.
  - A cute appearance, voice and language style made customers more tolerant of an AI assistant's service
    failures.
  - Two mediating routes: tenderness, and performance expectancy. The abstract does not state the
    direction; the likely reading is that cuteness lowers what customers expect.
  - The effect was bounded by how severe the failure was and by time pressure.
- **Zebrowitz & Montepare (2008).** *Social and Personality Psychology Compass*,
  doi:10.1111/j.1751-9004.2008.00109.x.
  - "Babyface overgeneralization": baby-like features make adults seem warmer, but also more naive, weaker
    and less competent.
  - Warmth and competence are the two primary dimensions of social judgment (Fiske, Cuddy & Glick 2007,
    *TiCS*, doi:10.1016/j.tics.2006.11.005).

**Strength:**
- Strong: baby schema increases cuteness and caretaking motivation.
- Weak or contested: cuteness improves careful or focused work (preregistered nulls; depends on the kind
  of cute).
- Moderate: cuteness increases tolerance of failure (one multi-experiment paper).

**Implications**
- **Don't justify creatures on productivity** ("kawaii helps you focus"). That evidence is contested. Justify
  them on legibility and enjoyment, and test enjoyment over weeks.
- **Aim for "competent-cute".** Cuteness earns forgiveness partly through performance expectancy, most
  likely by lowering it (Lv), and babyfaced features signal lower competence (Zebrowitz). That is the wrong
  signal for an agent trusted to change code. In practice:
  - geometric and restrained shapes;
  - mild baby schema only: a rounded body, slightly large eyes;
  - no infantile cues: no tiny limbs, no tears, no baby talk;
  - inside the Island's white-on-black ink, with no gradients.
- **Expect people to play with them.** Cute things invite poking, so people will click, hover and drag them.
  Either give that a harmless, brief response or keep the creature inert outside its row. Play must never
  get in the way of Allow and Deny.
- **Don't count on cuteness to soften real failures.** The tolerance effect weakens with severity and time
  pressure (Lv), which is exactly when a broken build matters.

---

## 4. The labor illusion and operational transparency

**Evidence**
- **Buell & Norton (2011).** *Management Science*, doi:10.1287/mnsc.1110.1376.
  - Five experiments simulated online travel and dating searches.
  - When the site showed the work being done for the user (in the travel case, a running list of the
    sites and fares being searched), people valued the service more.
  - People could even prefer a longer wait to instant, identical results.
  - Perceived effort and reciprocity explained the effect.
- **Buell, Kim & Tsay (2017).** *Management Science*, doi:10.1287/mnsc.2015.2411.
  - In food-service field and lab experiments, customers could see the cooks and cooks could see the
    customers.
  - Customer-reported quality rose 22.2%, and throughput time fell 19.2%.
- **Buell, Porter & Norton (2021).** *MSOM*, doi:10.1287/msom.2020.0877. Boston 311 app users who received
  photos of the city fixing their reports submitted 60% more requests over the next 13 months.
- **Limits.**
  - Gnewuch et al. (2022), *Business & Information Systems Engineering*, doi:10.1007/s12599-022-00755-x:
    a chatbot's delayed response had opposing effects, raising social presence but changing usage
    intentions. The effects were moderated by users' prior experience.
  - Bansal et al. (2021): showing an AI's reasoning raised acceptance whether or not the AI was right.
  - Maister (§5): filler unrelated to the service (on-hold Muzak) annoys. Filler related to the service
    (menus while you wait) helps.

**Strength: Moderate.** The evidence is mostly lab simulations of consumer services plus a few field
studies. It has not been tested on expert users supervising AI agents.

**Implications**
- **Show real work, not generic busyness.** The effect came from specific evidence of work done for this
  user (the actual fares being searched). A bouncing creature is closer to hold music than to the fare
  list. Drive the creature's activity from real agent events, and keep the real evidence one hover away
  (one line of current activity).
- **Never stage busyness.** Don't add delay or theatre when the agent is idle or stalled. How users react to
  a delay depends on their prior experience (Gnewuch), so a trick tuned on novices may not carry over to
  developers, and staging it is deceptive anyway. If no tool events arrive for a while, the creature slows
  to rest.
- **Pair the effort display with outcome honesty.** Transparency raises perceived value regardless of
  quality (Bansal). Done is not verified, and failures are shown plainly.
- **Don't twitch on every tool call in the closed notch.**
  - That would create a motion onset every few seconds, which captures attention (§7).
  - In the notch, bind activity to one continuous parameter that changes gradually.
  - Keep discrete "work beats" for the open board, where the user is already looking and the benefit
    applies.

---

## 5. Waiting and progress indicators

**Evidence**
- **Maister (1985), "The Psychology of Waiting Lines."** In Czepiel, Solomon & Surprenant (eds.), *The
  Service Encounter*. Text: https://davidmaister.com/articles/the-psychology-of-waiting-lines/
  - Occupied time feels shorter than unoccupied time.
  - Waits before the process starts feel longer than waits once it has started.
  - Anxiety, uncertainty and unexplained waits all make waits feel longer.
  - Satisfaction = perception − expectation.
- **Myers (1985).** CHI, doi:10.1145/1165385.317459. People prefer to have percent-done indicators.
- **Nah (2004).** *Behaviour & Information Technology*, doi:10.1080/01449290410001669914.
  - Feedback lengthens how long users will wait.
  - With no feedback, the tolerable wait for a web page was about 2 s.
- **NN/g, Sherwin (2014), "Progress Indicators Make a Slow System Less Insufferable."**
  https://www.nngroup.com/articles/progress-indicators/
  - Reports a study in which a looped progress bar made people willing to wait about three times longer.
  - Looped spinners suit waits of 2–10 s.
  - Beyond 10 s, an indefinite loop leaves users unsure whether the system is working or stuck.
- **NN/g, Nielsen, "Response Times: The 3 Important Limits"** (from *Usability Engineering*, 1993).
  https://www.nngroup.com/articles/response-times-3-important-limits/
  - 0.1 s feels instant.
  - 1 s keeps the flow of thought.
  - 10 s is the limit of attention. Beyond it, users turn to other tasks and need to know when the system
    will be done.
- **Harrison et al. (2007).** UIST, doi:10.1145/1294211.1294231. How a bar moves changes perceived
  duration, and users dislike pauses, especially near the end.
- **Harrison, Yeo & Hudson (2010).** CHI, doi:10.1145/1753326.1753556. Backward-moving, decelerating ribbing
  made a bar feel about 11% faster.

**Strength:** the principles are Strong. Specific magnitudes (3×, 11%) come from single studies.

**Implications**
- **Design for the callback, not the watch.** Agent runs last minutes, far beyond 10 s, so users will switch
  tasks rather than watch. The board's job is reassurance plus a reliable callback, like the DMV call-back
  in NN/g's article.
- **A cute loop only helps the anxious minority** who stare at the notch, because only they experience the
  wait as occupied time.
- **A working creature must change over time.** On a 20-minute task, an indefinite loop stops meaning
  anything after about 10 s. Something must change with time or activity: the ticking age on hover, the
  one-line activity. A stalled agent must look different from a working one.
- **Make "needs you" impossible to confuse with "working".** Anxiety lengthens waits, and the most valuable
  thing to tell a waiting user is "not stuck, not waiting for you".
- **Never fake progress or show a stall near the end.** If progress is unknown, don't imply it: no creature
  that grows toward "almost finished".

---

## 6. Gaze and eyes

**Evidence**
- **Friesen & Kingstone (1998).** *Psychonomic Bulletin & Review*, doi:10.3758/BF03208827. When a
  schematic face's pupils look to one side, observers' attention shifts that way, even though the gaze
  predicts nothing.
- **Driver et al. (1999).** *Visual Cognition*, doi:10.1080/135062899394920. Attention still follows seen
  gaze when observers know the target is four times more likely on the other side.
- **Frischen, Bayliss & Tipper (2007).** *Psychological Bulletin*, doi:10.1037/0033-2909.133.4.694. Review:
  gaze cueing is robust.
- **Wiese et al. (2012).** *PLoS ONE*, doi:10.1371/journal.pone.0045391. Gaze cueing is stronger when
  observers believe the eyes belong to an intentional agent.
- **Direct gaze.**
  - von Grünau & Anston (1995), *Perception*, doi:10.1068/p241297: a straight gaze is found faster among
    averted gazes ("stare in the crowd"), also with schematic eyes.
  - Senju & Hasegawa (2005), *Visual Cognition*, doi:10.1080/13506280444000157: a face looking at you
    makes it slower to move attention elsewhere.
- **Faces capture attention.** Langton et al. (2008), *Cognition*, doi:10.1016/j.cognition.2007.07.012:
  irrelevant faces slowed search for other targets. These were photographic faces; the effect for schematic
  faces is untested here.
- **"Watching eyes."**
  - Bateson, Nettle & Roberts (2006), *Biology Letters*, doi:10.1098/rsbl.2006.0509: a picture of eyes
    above an honesty box roughly tripled payments.
  - Northover et al. (2017), *Evolution and Human Behavior*, doi:10.1016/j.evolhumbehav.2016.07.001: two
    meta-analyses found artificial eyes do not increase generosity.
  - Dear, Dutton & Fox (2019), same journal, doi:10.1016/j.evolhumbehav.2019.01.006: across 15
    experiments, eye images reduced antisocial behavior by about 35%.

**Strength:**
- Strong: gaze cueing and the detection of direct gaze.
- Contested: watching-eyes effects on cooperation (small samples, failed replications).

**Implications**
- **Eyes are the strongest attention tool the creature has.** Spend them only where you want attention.
- **Default: no eye contact.** While working, eyes rest on the creature's work (down or inward) or are half
  closed.
- **"Needs you": turn to face the user.**
  - A direct gaze pops out among averted ones and holds attention.
  - When the pointer comes near, the creature's eyes may follow it, but only for sessions that need the
    user.
- **Never have every creature track the cursor.** Gaze cueing is reflexive even when it misleads (Driver),
  so a row of tracking eyes keeps pulling attention to the notch and reads as surveillance.
- **In the open board, a needs-you creature can glance at its row's Allow button.** Gaze cueing helps the
  user find it.
- **Two dots are enough.** Schematic eyes are sufficient for cueing.
- **Don't cite the watching-eyes effect as a benefit.** It is shaky, and it makes the product feel as if it
  is watching the user.
- **Faces in the periphery cost attention even when irrelevant.** In the closed notch, a working creature can
  be faceless or have its eyes closed.

---

## 7. Motion in peripheral vision; calm technology; interruption costs

**Attention capture**
- **Abrams & Christ (2003).** *Psychological Science*, doi:10.1111/1467-9280.01458.
  - "Motion per se does not automatically attract attention."
  - The onset of motion does: an item that had just started moving was found fastest. A moving item among
    static ones had no advantage.
- **Franconeri & Simons (2003).** *Perception & Psychophysics*, doi:10.3758/BF03194829. Objects that
  translate or loom (approach) capture attention; receding objects do not.
- **Simons, Franconeri & Reimer (2000).** *Perception*, doi:10.1068/p3104. Changes that are gradual enough
  do not draw attention, and large changes can go unnoticed.
- **Rensink, O'Regan & Clark (1997).** *Psychological Science*, doi:10.1111/j.1467-9280.1997.tb00427.x.
  Changes without a visible transient are often missed (change blindness).
- **Search asymmetry.** Finding a moving target among stationary distractors is efficient; the reverse is
  not. Royden, Wolfe & Klempen (2001), *Perception & Psychophysics*, doi:10.3758/BF03194410.

**Motion in the periphery**
- **Bartram, Ware & Calvert (2003), "Moticons."** *IJHCS*, doi:10.1016/S1071-5819(03)00021-1.
  - Simple motions are detected and identified better than changes of color or shape, especially in the
    periphery.
  - According to citing papers, anchored (in-place) motions were less distracting than traveling ones.
- **Rosenholtz (2016).** *Annual Review of Vision Science*, doi:10.1146/annurev-vision-082114-035733.
  Peripheral vision has poorer acuity and color perception and suffers crowding, but handles gist and motion
  well.
- **Burke et al. (2005).** *ACM TOCHI*, doi:10.1145/1121112.1121116.
  - Flashing banners raised perceived workload.
  - Animated and static ads both slowed search.
  - People rarely looked at the banners and remembered animated ones worse than static ones.

**Calm technology and ambient displays**
- **Weiser & Brown (1996), "Designing Calm Technology."** Their example is Natalie Jeremijenko's Dangling
  String, which shows network traffic by how much a string twitches, readable without looking at it.
- **Amber Case (2015), *Calm Technology* (O'Reilly).** Principles at https://calmtech.com/:
  - technology should require the smallest possible amount of attention;
  - it should make use of the periphery, moving easily into the center and back;
  - it can communicate without speaking;
  - machines shouldn't act like humans;
  - a tea kettle stays quiet until it sings.
- **Mankoff et al. (2003).** CHI, doi:10.1145/642611.642642. Heuristics for evaluating ambient displays.
- **Matthews et al. (2004).** UIST, doi:10.1145/1029632.1029676. Notification levels: *ignore →
  change-blind → make aware → interrupt → demand action*, with a transition designed for each level.

**Interruptions**
- **Mark, Gudith & Klocke (2008).** CHI, doi:10.1145/1357054.1357072. Interrupted people finish faster, but
  with more stress, frustration, time pressure and effort.
- **Iqbal & Horvitz (2007).** CHI, doi:10.1145/1240624.1240730.
  - After answering email or IM alerts, users often took 10 or more minutes to return to the suspended task.
  - They visited other applications on the way.
  - Exact figures differ between citing papers.
- **Iqbal & Bailey (2008).** CHI, doi:10.1145/1357054.1357070. Delivering notifications at breakpoints
  reduced frustration and reaction time compared with delivering them immediately.
- **Ancker et al. (2017).** *BMC Medical Informatics and Decision Making*, doi:10.1186/s12911-017-0430-8.
  Clinicians accepted alerts less often as repeated alerts accumulated (alert fatigue).

**Platform and accessibility guidance**
- **Apple HIG, Motion.**
  - "Add motion purposefully… Gratuitous or excessive animation can distract."
  - "Make motion optional… avoid using it as the only way to communicate important information."
  - Avoid motion on interactions that happen often.
  - In visionOS, people are particularly sensitive to motion in peripheral vision.
- **Apple HIG, Live Activities.**
  - Animations are capped at 2 s, and should reinforce information and draw attention to updates.
  - "If the underlying content or status remains the same, maintain the same display."
  - Alert only for essential updates.
  - "Don't add elements to your app that draw attention to the Dynamic Island."
- **Apple HIG, Accessibility.** Under Reduce Motion, reduce "automatic and repetitive animations, including
  zooming, scaling, and peripheral motion."
- **WCAG 2.2, SC 2.2.2 Pause, Stop, Hide (Level A).** Moving content that starts automatically, lasts more
  than 5 s and is shown alongside other content needs a way to pause, stop or hide it.

**Precedent.** RunCat (Kyome, https://kyome.io/runcat/) puts a running cat in the macOS menu bar; its speed
shows CPU load. It is continuous motion that encodes one live value.

**Strength:**
- Strong: motion onset and looming capture attention.
- Strong: peripheral motion is detected; Moderate: how distracting it is.
- Strong: interruption costs; Moderate: breakpoint timing.

**Implications**

Map each state to a notification level, with a motion budget per level. The numbers are starting values to
test, derived from the evidence, not measured in it.

| State | Level | Motion in the closed notch |
|---|---|---|
| Working | ignore / change-blind | Static, or one anchored, shared, slow loop (≤ 1 pt amplitude, period ≥ 2.5 s). Any rate change fades over ≥ 1 s. No onsets. |
| Done, unread | make aware | One short transition (≤ 600 ms) when it finishes, then still. |
| Needs you | interrupt | One onset: anticipation, a small loom (≤ 15% scale), eyes to the user, amber. Re-cue only at a breakpoint (the user switches app or window), at most once or twice, never on a timer. |
| Failed | make aware (interrupt only if it blocks the user) | One transition, then a static red mark. |
| Status unavailable | ignore | Dim and still (the current spec). |

- **Only one thing moves at a time in the closed notch.** Because of the search asymmetry, a needs-you
  creature among moving creatures is hard to find; among still ones it pops out. While the needs-you onset
  plays, the others should be still. (Untested idea: briefly pausing the others when one needs you.)
- **Don't rely on color in the periphery.** Color perception is poorer there and items crowd. Carry state in
  motion onset, brightness and silhouette, use amber and red as reinforcement, and put the words in the panel.
- **A looping notch creature needs an off switch.** Under WCAG 2.2.2 and Apple's Reduce Motion guidance, a
  loop longer than 5 s needs a setting to stop it, and must stop when Reduce Motion is on.
- **Animate the aggregate, not each agent.** The Dangling String and RunCat show continuous motion can be
  calm when it is anchored and its rate encodes something real. But each shows one ambient variable, not N
  agents each asking for a glance. Give all working agents one shared rhythm rather than N separate ones.

---

## 8. Attachment to virtual beings; guilt mechanics; Clippy and Mico

**Evidence**
- **The Tamagotchi effect.**
  - Early Tamagotchis (1996) "died" within about half a day of neglect.
  - Owners carried them everywhere, schools banned them, and later models added a pause.
  - Source: Wikipedia, "Tamagotchi effect", whose article is flagged as essay-like.
- **Dodd, Fowler & Lottridge (2025).** *Entertainment Computing*, doi:10.1016/j.entcom.2025.100958.
  Narrative review of 45 articles on virtual pets. Themes include life and death, health and habits, and
  ethics.
- **Kaplan (2000), "Free creatures: the role of uselessness in the design of artificial pets."**
  Successful artificial pets are *useless*: they do no service task. That is part of why their failures
  are endearing.
- **Fish'n'Steps (Lin et al. 2006).** UbiComp, doi:10.1007/11853565_16.
  - Daily step counts made a virtual fish grow.
  - According to citing papers, a sad fish made some users disengage because they did not want to see it.
  - The authors advise avoiding self-disappointment.
  - Interest also declined over time.
- **UbiFit Garden (Consolvo et al. 2008).** UbiComp, doi:10.1145/1409635.1409644. Participants who had a
  glanceable garden as their phone wallpaper maintained their activity over the holidays; those without it
  dropped.
- **Finch** (self-care pet app). Its pitch is "take care of your pet by taking care of yourself".
  - App Store rating 4.9 from about 761K ratings, with an Editors' Choice.
  - Reviews say users do the exercises "in order to help Finch": caretaking motivation is the lever.
  - No peer-reviewed outcome study was found.
- **Duolingo.**
  - Yancey & Settles (2020), KDD, doi:10.1145/3394486.3403351: bandit-optimized reminders raised daily
    active users 0.5% and new-user retention 2%. This is the industrial scale at which mascot-voiced nudges
    get tuned.
  - Castro & Valença (2025), IHC, doi:10.5753/ihc.2025.10795: a qualitative analysis found manipulative
    patterns, namely excessive notifications and emotionally charged visuals.
  - Gray et al. (2018), CHI, doi:10.1145/3173574.3174108: dark patterns put shareholder value ahead of user
    value.
- **De Freitas, Oguz-Uguralp & Kaan-Uguralp (2025).** arXiv:2508.19258.
  - Companion apps used emotional manipulation (guilt, fear of missing out, "needy" language) in 37% of
    1,200 real goodbyes.
  - In preregistered experiments (n = 3,300), these tactics boosted engagement after the goodbye up to 14×.
  - They also raised perceived manipulation, intent to quit and negative word of mouth.
- **De Freitas (2026).** arXiv, "AI Companions as Hyper Attachment and Caregiving Targets." Simulating the
  AI's own distress recruits users' caregiving motives, which makes leaving costly.
- **Clippy.**
  - The Office Assistant (Office 97) was built on the Lumière research (Horvitz et al. 1998,
    arXiv:1301.7385).
  - It was widely reviled as intrusive and annoying, and Office XP (2001) turned it off by default.
    Microsoft marketed that change with an ad campaign about the paperclip losing its job (Wikipedia,
    "Office Assistant").
  - Whitworth (2005), *Behaviour & Information Technology*, doi:10.1080/01449290512331333700, describes
    Clippy as impolite software. Politeness means: respect user choice, disclose yourself, offer useful
    choices, remember past choices.
  - Swartz (2003), Stanford thesis, "Why People Hate the Paperclip."
  - Horvitz (1999), CHI, doi:10.1145/302979.303030, mixed-initiative principles, among them:
    - weigh the user's attention when timing a service;
    - allow efficient invocation and dismissal;
    - minimize the cost of poor guesses.
- **Mico.**
  - Microsoft introduced Mico on Oct 23, 2025 (The Verge, Tom Warren,
    https://www.theverge.com/news/804106/microsoft-mico-copilot-ai-assistant-clippy).
  - It is an expressive "bouncing orb" in Copilot's voice mode that reacts in real time to what you say.
  - It is on by default and can be turned off, and it includes a Clippy Easter egg.
  - Wikipedia's Microsoft Copilot article (Oct 2026) says Mico is among the features removed when consumer
    Copilot merged with Microsoft 365 Copilot in 2026. The cited Windows Central article lists group chats,
    podcasts and Deep Research and does not mention Mico in its retrievable text. Treat the removal as
    unverified.

**Strength:** mostly qualitative or case evidence. De Freitas 2025 has preregistered experiments.
Fish'n'Steps and UbiFit are small field studies.

**Implications**
- **Plan for attachment.** Users will name the creatures. Make a creature belong to an agent or project (a
  stable crew) rather than being born and killed with each session. Frequent "deaths" are the Tamagotchi
  distress pattern, and recognizing an individual needs it to persist.
- **No creature ever suffers because it was ignored.**
  - A creature waiting on the user does not get sadder, more frantic or louder over time.
  - No streaks, no "miss you", no guilt when the user quits.
  - Sad displays cause avoidance (Fish'n'Steps); needy appeals raise intent to quit (De Freitas).
- **A useful creature that fails is a broken tool, not an endearing pet** (Kaplan). The Failed state is a
  factual tool state.
- **Clippy's lessons, concretely:**
  - Never proactive: react only to state changes in the user's own sessions; never offer unsolicited
    suggestions.
  - Dismissible: provide a static-glyph mode and honor Reduce Motion. Office XP had to turn Clippy off by
    default.
  - Never cover or block the user's work.
  - Remember dismissals.
- **Mico is the modern version of the same lessons:** reactive to the user, optional.

---

## 9. Animation principles for characters in UI

**Evidence**
- **The 12 principles.**
  - Thomas & Johnston (1981), *The Illusion of Life: Disney Animation*.
  - Lasseter (1987), SIGGRAPH, doi:10.1145/37401.37407.
  - They include squash and stretch, anticipation, slow in and slow out, follow-through, timing,
    exaggeration and appeal.
- **Chang & Ungar (1993).** UIST, doi:10.1145/168642.168647. In the Self UI, cartoon techniques made
  changes easier to follow and less startling: anticipation with a small contrary motion, a faster middle
  than ends, motion blur, smooth arrivals and departures.
- **Dragicevic et al. (2011).** CHI, doi:10.1145/1978942.1979233. For tracking objects through animated
  transitions, slow-in/slow-out pacing beat constant speed and the other pacings tested.
- **Takayama, Dooley & Ju (2011).** HRI, doi:10.1145/1957656.1957674. Online video experiment, N = 273.
  - Showing forethought (anticipation before acting) and reacting to the outcome (success or failure) made
    the robot more readable.
  - They also shaped how people judged it: citing papers report higher perceived competence and
    approachability.
- **Ribeiro & Paiva (2012).** HRI, doi:10.1145/2157689.2157814. Animation principles helped people
  understand the emotions of a robot with limited facial expression.
- **Kwon, Huang & Dragan (2018).** HRI, doi:10.1145/3171221.3171276. Motions that express incapability
  (what the robot was trying to do and why it could not) improved users' view of the robot and their
  willingness to collaborate.
- **Timing guidance.**
  - NN/g (Laubheimer 2020), https://www.nngroup.com/articles/animation-duration/: most UI animations
    should take 100–500 ms, and 400 ms is already slow. The more often an animation plays, the subtler and
    shorter it should be.
  - Apple Live Activities caps animations at 2 s.

**Strength:** practitioner canon plus a handful of controlled studies.

**Implications**
- **Apply the principles to transitions, not idle loops.**
  - Anticipation: an 80–120 ms wind-up before the needs-you hop.
  - Follow-through and settle: springs with little or no bounce, as in Fovea's motion notes.
  - Slow in, slow out.
- **Use "reaction to outcome" for Done and Failed.** One brief reaction tells the outcome better than a
  static badge, and it is the moment animation earns its place. Keep a reaction to about 600 ms or less, and
  the whole sequence to 2 s or less.
- **For failure, express incapability.** A pose showing it tried and stopped (it bumps into a wall) says
  more than a generic sad face, and it needs no persona.
- **Keep squash and stretch small at this size.** On a 16–18 pt creature, stay at or below about 10% scale
  change. Exaggeration reads at large sizes; in the periphery, a big squash is just a flicker.

---

## 10. Closure and completion

**Evidence**
- **Zeigarnik (1927).** *Psychologische Forschung* 9. People recalled interrupted tasks better than
  finished ones.
- **Ghibellini & Meier (2025).** *Humanities and Social Sciences Communications*,
  doi:10.1057/s41599-025-05000-w. Meta-analysis:
  - no memory advantage for unfinished tasks;
  - but a general tendency to resume interrupted tasks (the Ovsiankina effect).
- **Masicampo & Baumeister (2011).** *JPSP*, doi:10.1037/a0024192. Unfinished goals cause intrusive thoughts
  and interfere with other work. Making a specific plan removed those effects.
- **Goal gradient.** Kivetz, Urminsky & Zheng (2006), *Journal of Marketing Research*,
  doi:10.1509/jmkr.43.1.39.
  - Effort speeds up as a reward gets closer.
  - Illusory progress speeds completion: a 12-stamp card with 2 free stamps beat a 10-stamp card.
- **Peak-end rule.**
  - Kahneman et al. (1993), *Psychological Science*, doi:10.1111/j.1467-9280.1993.tb00589.x: people chose to
    repeat a longer painful episode that ended less badly.
  - Redelmeier & Kahneman (1996), *Pain*, doi:10.1016/0304-3959(96)02994-6: patients' retrospective
    ratings followed the worst and the final moments.
  - Alaybek et al. (2022), *OBHDP*, doi:10.1016/j.obhdp.2022.104149: a meta-analysis found the effect large
    and robust (citing papers report r ≈ 0.58), with duration mattering little.

**Strength:**
- Weak: the Zeigarnik memory effect.
- Moderate: the Ovsiankina resumption effect.
- Moderate to Strong: goal gradient.
- Strong: peak-end.

**Implications**
- **Don't make "done, unread" nag.** The Zeigarnik case for a persistent open loop is weak. The robust effect
  is that people want to resume, so a calm, static "holding a result" pose is enough to draw them back.
- **Offer a way to defer on purpose.** A "later" that sets a specific plan (a time, or a moment such as
  "when I finish this") removes the intrusive pull of the open loop, according to Masicampo & Baumeister.
- **Peaks and ends dominate memory.**
  - Make completion a small positive peak: one brief, satisfying beat.
  - When the user opens the result, end on resolution: the creature settles or goes home.
  - Failures are negative peaks. Make the fix (rerun, retry) the end, so the failure isn't the last thing
    remembered.
- **No illusory progress.** The goal gradient shows fake progress changes behavior, which in a work tool is
  manipulation. NN/g and Harrison show users dislike progress that stalls near the end.

---

## 11. Choice and targeting: a row of small targets at the top of the screen

**Evidence**
- **Fitts's law.**
  - Fitts (1954), *Journal of Experimental Psychology*, doi:10.1037/h0055392.
  - MacKenzie (1992), *Human–Computer Interaction*, doi:10.1207/s15327051hci0701_3.
  - Movement time grows with distance and shrinks with target width.
  - NN/g (Budiu 2022, https://www.nngroup.com/articles/fitts-law/): screen edges make targets effectively
    infinite, because the cursor stops there. That is why macOS puts menus on the top edge.
- **Apple HIG, Accessibility.** macOS default control size is 28×28 pt, minimum 20×20 pt. Spacing between
  controls matters as much as their size.
- **Hick (1952).** *Quarterly Journal of Experimental Psychology*, doi:10.1080/17470215208416600. Choice
  reaction time grows with information, roughly the log of the number of equally likely options. Caveat: it
  describes unpracticed choices among equally likely options; sorting and practice largely remove it.
- **Subitizing.** Trick & Pylyshyn (1994), *Psychological Review*, doi:10.1037/0033-295X.101.1.80.
  - Up to about 4 items are enumerated fast and accurately (40–100 ms per item).
  - Beyond that, counting is slow and error-prone (250–350 ms per item).
- **Gestalt grouping.**
  - Wagemans et al. (2012), *Psychological Bulletin*, doi:10.1037/a0029333: proximity, similarity, common
    fate, synchrony, common region.
  - Sekuler & Bennett (2001), *Psychological Science*, doi:10.1111/1467-9280.00382: elements that change
    together, even only in brightness, group very strongly.

**Strength:**
- Very strong: Fitts's law.
- Strong in the lab, weak for familiar interfaces: Hick's law.
- Strong: subitizing and grouping.

**Implications**
- **Use the top edge, with generous hit areas.**
  - Put the creatures flush with the top edge, which gives them effectively infinite height.
  - Give each a hit area at least 28 pt wide (20 pt minimum), even if the drawing is only 14–18 pt.
  - Hit areas should fill the gaps between creatures.
  - The camera housing hides the cursor, so place targets beside the notch, not under it.
- **Make the choice trivial rather than fast.** Order by urgency (needs-you first, the spec's order), so the
  user never chooses among N creatures and Hick's law barely applies.
- **Cap distinct creatures at about 4 in the closed notch.** Beyond 4, users stop seeing "how many" at a
  glance and start counting. Fovea shows no counts, so the grouping has to be visual: show needs-you
  creatures individually, merge working ones into one group, and use proximity and common fate.
- **Synchronize working creatures.**
  - With one shared tempo and phase, they read as one quiet group, and the needs-you creature breaks the
    rhythm.
  - Fovea's motion notes say lockstep feels mechanical, but here grouping is the point. If you want organic
    variety, vary the shape, not the phase.

---

## What the research predicts users will feel and do

| When | Likely feeling | Likely behavior | Basis |
|---|---|---|---|
| First days | Delight, "it's alive", curiosity | More glances at the notch, hovering and clicking creatures, naming them, screenshots | Heider & Simmel; Sherman & Haidt (cute → play); Kanda 2004 (novelty) |
| Weeks 2–4 | Habituation; constant motion becomes background or irritation | Stop noticing working loops; some switch creatures off | Kanda 2004 (interaction fell sharply by week 2); Burke 2005; Ancker 2017 |
| Long runs | Reassured, more patient; agent work seems more valuable | Check the terminal less often | Maister; Buell & Norton; Nah 2004 |
| Agent needs them | Quick notice if only that creature moves; slow notice if all move | Faster replies, but an interruption cost if the cue fires mid-task | Abrams & Christ; Royden; Mark 2008; Iqbal & Bailey |
| Minor failure | Softened, forgiving | Retry rather than abandon | Lv 2021; de Visser 2016 |
| Failure under stress | Amplified anger at a "cute" agent | Blame and distrust, both of the persona and of the product | Crolic 2022; Lv (time-pressure boundary) |
| Over months | More trust in agent output | Less careful review of diffs (over-reliance) | Waytz; de Visser; Bansal; Cohn; Parasuraman & Riley |
| Attachment | Care; guilt if a creature looks neglected | Avoid sad displays; check compulsively if guilt is designed in | Fish'n'Steps; Tamagotchi; De Freitas 2025 |

---

## Where it can go wrong: risk register

| Risk | Mechanism and source | Early sign | Mitigation |
|---|---|---|---|
| Attention tax | Peripheral motion is noticed and adds workload (Bartram; Burke; Apple HIG) | Users report the notch is "distracting"; more idle hovers with no action | Working creatures still or near-still in the closed notch; one mover at a time |
| Signal dilution | Onset captures, ongoing motion does not; moving-among-moving is a hard search (Abrams & Christ; Royden) | Needs-you response time is no better, or worse, than the glyph design | Needs-you is the only onset; others still during it |
| Over-trust | Anthropomorphism and visible effort raise trust whatever the quality (Waytz; Bansal) | Fewer diff opens before accepting | Honest stale state; done never looks verified; plain failures |
| Competence discount | Babyface overgeneralization; cuteness lowers performance expectations (Zebrowitz; Lv) | Users call it "toy-like"; trust ratings drop for complex tasks | Competent-cute styling; no infantile cues |
| Anger amplification | Humanized agent plus angry user → expectancy violation (Crolic) | Complaints spike after failures | Persona-free Failed and Allow/Deny states |
| Guilt and dark patterns | Caregiving capture, needy appeals (De Freitas; Duolingo critique) | Users say they feel bad leaving sessions waiting | No suffering, no escalation, no streaks, no "miss you" |
| Clippy effect | Unsolicited, uncontrollable, impolite presence (Whitworth; Horvitz) | Opt-out rate climbs | Never proactive; one-click static mode; honor Reduce Motion |
| Illegible states | Acuity, crowding and poor color in the periphery (Rosenholtz) | Users confuse done with idle, or failed with needs-you | Coarse cues (onset, brightness, silhouette) plus words in the panel |
| Novelty decay | Interaction drops after week 1 (Kanda) | Hovers per day fall | Judge the design at week 3, not day 1 |
| Accessibility | Vestibular sensitivity; WCAG 2.2.2's 5 s rule | Reduce Motion users see loops | Static fallback; a setting to stop loops |
| Spec conflict | AGENT_PANEL.md "No decoration: no mascots" | — | Creature replaces the glyph or badge, or amend the spec explicitly |

---

## Design rules, ranked by strength of evidence and impact

1. **The creature is the state glyph, not decoration.** It replaces the badge or glyph and carries state.
   This satisfies "Illustration only where it carries state."
2. **One mover at a time.** In the closed notch nothing moves except a creature whose state just changed.
   Working creatures are still or near-still: anchored, ≤ 1 pt amplitude, period ≥ 2.5 s, one shared phase.
3. **"Needs you" is a single motion onset.** A wind-up, a small loom (≤ 15%), eyes to the user, then amber,
   held still. Re-cue only when the user switches app or window, at most twice, never on a timer.
4. **Eyes look at the user only when that session needs the user.** Otherwise they rest on the creature's
   work. Only needs-you creatures follow the pointer. Never all of them.
5. **Activity comes from real events.** Gradual rate changes in the notch; discrete work beats only in the
   open board. No staged busyness and no added delay. Stalled agents visibly rest.
6. **Failure and high-stakes asks drop the persona.** Plain words, red or amber, Allow/Deny unobstructed. No
   apologetic faces. A pose that says "tried and stopped" is acceptable.
7. **No creature ever suffers or escalates because it was ignored.** No guilt, no streaks, no "miss you",
   no creature deaths. Creatures belong to an agent or project and go home when sessions end.
8. **Every animation is a transition of 100–500 ms, and each sequence takes ≤ 2 s.** Use anticipation,
   slow-in/slow-out and springs with little or no bounce. Use one reaction beat for Done and for Failed.
9. **State must never depend on motion, color or face alone.** Pair silhouette or brightness with words in
   the panel. Provide a static mode and honor Reduce Motion (WCAG 2.2.2; Apple HIG).
10. **Built for the top edge and for a glance.**
    - Hit areas ≥ 28 pt wide (minimum 20 pt), flush with the top edge.
    - Sorted by urgency.
    - At most about 4 distinct creatures in the closed notch, with working ones merged into one group.

Secondary rules:
- **Competent-cute styling:** geometric, mild baby schema, white ink on black.
- **Never proactive or verbal:** no unsolicited suggestions, no "I".
- **Done, unread** is a calm "holding a result" pose with no loop. Opening it ends on resolution.
- **Offer "later"** as a deliberate plan.

---

## How to test before committing

Run a 3-week within-subjects field comparison: creatures against the current Sections or Badges design,
switching arms weekly with the order counterbalanced. Log:
- **Needs-you latency:** time from the request to the user's response (median and 90th percentile), plus
  missed or late requests.
- **Attention cost:**
  - hovers on the Island with no action ("idle checks");
  - self-reported distraction (a short NASA-TLX after work blocks);
  - if available, glance counts from an eye tracker on a few machines.
- **Trust calibration:**
  - how often users open a diff before accepting;
  - a short trust-in-automation scale;
  - whether trust differs between correct and incorrect agent outcomes, since that gap is what calibration
    means.
- **Affect over time:** enjoyment and annoyance on day 2, day 7 and day 20; opt-out rate; share of
  Reduce Motion users.
- **Failure reactions:** ratings right after a failed session in each arm. Crolic predicts the creature arm
  is worse when the user is under stress.

Decision rule: adopt creatures only if needs-you latency and idle checks are no worse than the glyph design
at week 3, and trust calibration does not get worse. Enjoyment alone is not enough.

---

## Evidence quality at a glance

| Claim | Strength | Note |
|---|---|---|
| Motion makes shapes read as agents | Strong | Replicated 1944 → 2019 |
| Anthropomorphism → trust and forgiveness | Moderate | Reverses with anger (Crolic); context-dependent (Cohn) |
| Baby schema → cuteness and care motivation | Strong | |
| Cute images → careful, focused work | Weak / contested | Two preregistered nulls (Ziv & Fox 2022); whimsical cute → indulgence |
| Cute AI → failure tolerance | Moderate | One multi-experiment paper; weaker under severity and time pressure |
| Labor illusion | Moderate | Consumer services; untested with expert agent supervisors |
| Progress feedback lengthens tolerable waits | Strong (direction) | Magnitudes (3×, 11%) from single studies |
| Gaze cueing; direct gaze pops out | Strong | |
| Watching eyes → cooperation | Contested | Generosity: null meta-analyses; antisocial: −35% meta-analysis |
| Motion onset and looming capture attention | Strong | Ongoing motion alone does not |
| Moticons: anchored motion less distracting | Moderate | Single lab; summarized via citing papers |
| Interruption costs; breakpoint timing helps | Strong / Moderate | Exact resumption times vary by study |
| Virtual-pet attachment and guilt effects | Weak to moderate | Mostly qualitative; De Freitas has preregistered experiments |
| Animation principles improve readability | Moderate | Canon plus a few controlled studies |
| Zeigarnik memory effect | Weak | 2025 meta-analysis: no memory advantage |
| Ovsiankina resumption tendency | Moderate | |
| Peak-end | Strong | 2022 meta-analysis |
| Fitts's law; screen-edge targets | Very strong | |
| Hick's law for familiar UIs | Weak predictor | Sorting and practice dominate |

---

## Sources

Animacy
- Heider, F., & Simmel, M. (1944). An experimental study of apparent behavior. *American Journal of
  Psychology*. doi:10.2307/1416950
- Ratajska, A., Brown, M., & Chabris, C. (2019 preprint). Attributing social meaning to animated shapes.
  doi:10.31234/osf.io/2d9xj
- Scholl, B. J., & Tremoulet, P. D. (2000). Perceptual causality and animacy. *TiCS*.
  doi:10.1016/S1364-6613(00)01506-0
- Tremoulet, P. D., & Feldman, J. (2000). Perception of animacy from the motion of a single object.
  *Perception*. doi:10.1068/p3101
- Gao, T., McCarthy, G., & Scholl, B. J. (2010). The wolfpack effect. *Psychological Science*.
  doi:10.1177/0956797610388814

Anthropomorphism and trust
- Epley, N., Waytz, A., & Cacioppo, J. T. (2007). On seeing human. *Psychological Review*.
  doi:10.1037/0033-295X.114.4.864
- Waytz, A., Heafner, J., & Epley, N. (2014). The mind in the machine. *JESP*. doi:10.1016/j.jesp.2014.01.005
- de Visser, E. J., et al. (2016). Almost human. *J. Exp. Psych.: Applied*. doi:10.1037/xap0000092
- Crolic, C., Thomaz, F., Hadi, R., & Stephen, A. T. (2022). Blame the bot. *Journal of Marketing*.
  doi:10.1177/00222429211045687
- Nass, C., & Moon, Y. (2000). Machines and mindlessness. *Journal of Social Issues*.
  doi:10.1111/0022-4537.00153
- Cohn, M., et al. (2024). Believing anthropomorphism. CHI EA. doi:10.1145/3613905.3650818
- Bansal, G., et al. (2021). Does the whole exceed its parts? CHI. doi:10.1145/3411764.3445717
- Parasuraman, R., & Riley, V. (1997). Humans and automation. *Human Factors*.
  doi:10.1518/001872097778543886
- Weizenbaum, J. (1966). ELIZA. *CACM*. doi:10.1145/365153.365168
- Abercrombie, G., et al. (2023). Mirages: On anthropomorphism in dialogue systems. EMNLP.
  doi:10.18653/v1/2023.emnlp-main.290
- Gibbons, S., Mugunthan, T., & Nielsen, J. (2023). The 4 degrees of anthropomorphism of generative AI.
  NN/g. https://www.nngroup.com/articles/anthropomorphism/

Cuteness
- Glocker, M. L., et al. (2009). Baby schema in infant faces. *Ethology*.
  doi:10.1111/j.1439-0310.2008.01603.x
- Sherman, G. D., Haidt, J., & Coan, J. A. (2009). Viewing cute images increases behavioral carefulness.
  *Emotion*. doi:10.1037/a0014904
- Nittono, H., et al. (2012). The power of kawaii. *PLoS ONE*. doi:10.1371/journal.pone.0046362
- Ziv, G., & Fox, O. (2022). Viewing cute images does not affect performance of computerized reaction time
  tasks. *Frontiers in Psychology*. doi:10.3389/fpsyg.2021.800543
- Fox, O., & Ziv, G. (2022). Cute images, dog owners and non-dog owners. *PeerJ*. doi:10.7717/peerj.14439
- Nenkov, G. Y., & Scott, M. L. (2014). "So cute I could eat it up". *JCR*. doi:10.1086/676581
- Sherman, G. D., & Haidt, J. (2011). Cuteness and disgust. *Emotion Review*.
  doi:10.1177/1754073911402396
- Lv, X., et al. (2021). Does a cute AI assistant soften the blow? *Annals of Tourism Research*.
  doi:10.1016/j.annals.2020.103114
- Zebrowitz, L. A., & Montepare, J. M. (2008). Social psychological face perception. *SPPC*.
  doi:10.1111/j.1751-9004.2008.00109.x
- Fiske, S. T., Cuddy, A. J. C., & Glick, P. (2007). Universal dimensions of social cognition. *TiCS*.
  doi:10.1016/j.tics.2006.11.005
- Kringelbach, M. L., et al. (2016). On cuteness. *TiCS*. doi:10.1016/j.tics.2016.05.003

Labor illusion
- Buell, R. W., & Norton, M. I. (2011). The labor illusion. *Management Science*.
  doi:10.1287/mnsc.1110.1376
- Buell, R. W., Kim, T., & Tsay, C.-J. (2017). Creating reciprocal value through operational transparency.
  *Management Science*. doi:10.1287/mnsc.2015.2411
- Buell, R. W., Porter, E., & Norton, M. I. (2021). Surfacing the submerged state. *MSOM*.
  doi:10.1287/msom.2020.0877
- Gnewuch, U., et al. (2022). Opposing effects of response time in human–chatbot interaction. *BISE*.
  doi:10.1007/s12599-022-00755-x

Waiting and progress
- Maister, D. H. (1985). The psychology of waiting lines. In *The Service Encounter*.
  https://davidmaister.com/articles/the-psychology-of-waiting-lines/
- Myers, B. A. (1985). The importance of percent-done progress indicators. CHI. doi:10.1145/1165385.317459
- Nah, F. F.-H. (2004). A study on tolerable waiting time. *BIT*. doi:10.1080/01449290410001669914
- Harrison, C., et al. (2007). Rethinking the progress bar. UIST. doi:10.1145/1294211.1294231
- Harrison, C., Yeo, Z., & Hudson, S. E. (2010). Faster progress bars. CHI. doi:10.1145/1753326.1753556
- Sherwin, K. (2014). Progress indicators make a slow system less insufferable. NN/g.
  https://www.nngroup.com/articles/progress-indicators/
- Nielsen, J. Response times: the 3 important limits. NN/g.
  https://www.nngroup.com/articles/response-times-3-important-limits/

Gaze and eyes
- Friesen, C. K., & Kingstone, A. (1998). The eyes have it! *PB&R*. doi:10.3758/BF03208827
- Driver, J., et al. (1999). Gaze perception triggers reflexive visuospatial orienting. *Visual Cognition*.
  doi:10.1080/135062899394920
- Frischen, A., Bayliss, A. P., & Tipper, S. P. (2007). Gaze cueing of attention. *Psychological Bulletin*.
  doi:10.1037/0033-2909.133.4.694
- Wiese, E., et al. (2012). I see what you mean. *PLoS ONE*. doi:10.1371/journal.pone.0045391
- von Grünau, M., & Anston, C. (1995). The detection of gaze direction: a stare-in-the-crowd effect.
  *Perception*. doi:10.1068/p241297
- Senju, A., & Hasegawa, T. (2005). Direct gaze captures visuospatial attention. *Visual Cognition*.
  doi:10.1080/13506280444000157
- Langton, S. R. H., et al. (2008). Attention capture by faces. *Cognition*.
  doi:10.1016/j.cognition.2007.07.012
- Bateson, M., Nettle, D., & Roberts, G. (2006). Cues of being watched. *Biology Letters*.
  doi:10.1098/rsbl.2006.0509
- Northover, S. B., et al. (2017). Artificial surveillance cues do not increase generosity. *EHB*.
  doi:10.1016/j.evolhumbehav.2016.07.001
- Dear, K., Dutton, K., & Fox, E. (2019). Do 'watching eyes' influence antisocial behavior? *EHB*.
  doi:10.1016/j.evolhumbehav.2019.01.006

Periphery, calm technology, interruptions
- Abrams, R. A., & Christ, S. E. (2003). Motion onset captures attention. *Psychological Science*.
  doi:10.1111/1467-9280.01458
- Franconeri, S. L., & Simons, D. J. (2003). Moving and looming stimuli capture attention. *P&P*.
  doi:10.3758/BF03194829
- Simons, D. J., Franconeri, S. L., & Reimer, R. L. (2000). Change blindness in the absence of a visual
  disruption. *Perception*. doi:10.1068/p3104
- Rensink, R. A., O'Regan, J. K., & Clark, J. J. (1997). To see or not to see. *Psychological Science*.
  doi:10.1111/j.1467-9280.1997.tb00427.x
- Royden, C. S., Wolfe, J. M., & Klempen, N. (2001). Visual search asymmetries in motion and optic flow
  fields. *P&P*. doi:10.3758/BF03194410
- Bartram, L., Ware, C., & Calvert, T. (2003). Moticons. *IJHCS*. doi:10.1016/S1071-5819(03)00021-1
- Rosenholtz, R. (2016). Capabilities and limitations of peripheral vision. *Annual Review of Vision
  Science*. doi:10.1146/annurev-vision-082114-035733
- Burke, M., et al. (2005). High-cost banner blindness. *ACM TOCHI*. doi:10.1145/1121112.1121116
- Weiser, M., & Brown, J. S. (1996). Designing calm technology. *PowerGrid Journal*.
- Case, A. (2015). *Calm Technology*. O'Reilly. Principles: https://calmtech.com/
- Mankoff, J., et al. (2003). Heuristic evaluation of ambient displays. CHI. doi:10.1145/642611.642642
- Matthews, T., et al. (2004). A toolkit for managing user attention in peripheral displays. UIST.
  doi:10.1145/1029632.1029676
- Mark, G., Gudith, D., & Klocke, U. (2008). The cost of interrupted work. CHI.
  doi:10.1145/1357054.1357072
- Iqbal, S. T., & Horvitz, E. (2007). Disruption and recovery of computing tasks. CHI.
  doi:10.1145/1240624.1240730
- Iqbal, S. T., & Bailey, B. P. (2008). Effects of intelligent notification management. CHI.
  doi:10.1145/1357054.1357070
- Ancker, J. S., et al. (2017). Effects of workload, work complexity, and repeated alerts on alert fatigue.
  *BMC Med Inform Decis Mak*. doi:10.1186/s12911-017-0430-8
- Apple Human Interface Guidelines.
  - Motion: https://developer.apple.com/design/human-interface-guidelines/motion
  - Live Activities: https://developer.apple.com/design/human-interface-guidelines/live-activities
  - Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- W3C WCAG 2.2, SC 2.2.2 Pause, Stop, Hide; SC 2.3.3 Animation from Interactions.
  https://www.w3.org/TR/WCAG22/
- Kyome. RunCat. https://kyome.io/runcat/

Attachment, guilt, Clippy, Mico
- Dodd, M., Fowler, A., & Lottridge, D. M. (2025). Purr-ogrammed love: a narrative review of virtual pets.
  *Entertainment Computing*. doi:10.1016/j.entcom.2025.100958
- Kaplan, F. (2000). Free creatures: the role of uselessness in the design of artificial pets.
- Lin, J. J., et al. (2006). Fish'n'Steps. UbiComp. doi:10.1007/11853565_16
- Consolvo, S., et al. (2008). Flowers or a robot army? UbiComp. doi:10.1145/1409635.1409644
- Finch: Self-Care Pet, App Store listing. https://apps.apple.com/us/app/finch-self-care-pet/id1528595748
- Yancey, K. P., & Settles, B. (2020). A sleeping, recovering bandit algorithm for optimizing recurring
  notifications. KDD. doi:10.1145/3394486.3403351
- Castro, J. V., & Valença, G. (2025). Teaching or manipulating? Bright and deceptive patterns in Duolingo.
  IHC. doi:10.5753/ihc.2025.10795
- Gray, C. M., et al. (2018). The dark (patterns) side of UX design. CHI. doi:10.1145/3173574.3174108
- De Freitas, J., Oguz-Uguralp, Z., & Kaan-Uguralp, A. (2025). Emotional manipulation by AI companions.
  arXiv:2508.19258
- De Freitas, J. (2026). AI companions as hyper attachment and caregiving targets. arXiv.
- Horvitz, E., et al. (1998). The Lumière project. UAI. arXiv:1301.7385
- Horvitz, E. (1999). Principles of mixed-initiative user interfaces. CHI. doi:10.1145/302979.303030
- Whitworth, B. (2005). Polite computing. *BIT*. doi:10.1080/01449290512331333700
- Swartz, L. (2003). Why people hate the paperclip (Stanford thesis).
- Wikipedia: "Office Assistant"; "Microsoft Copilot"; "Tamagotchi effect" (accessed 2026-10-08).
- Warren, T. (2025, Oct 23). Meet Mico, Microsoft's AI version of Clippy. *The Verge*.
  https://www.theverge.com/news/804106/microsoft-mico-copilot-ai-assistant-clippy
- Kanda, T., et al. (2004). Interactive robots as social partners and peer tutors for children. *HCI*.
  doi:10.1207/s15327051hci1901&2_4
- Leite, I., Martinho, C., & Paiva, A. (2013). Social robots for long-term interaction: a survey. *IJSR*.
  doi:10.1007/s12369-013-0178-y

Animation
- Thomas, F., & Johnston, O. (1981). *The Illusion of Life: Disney Animation*.
- Lasseter, J. (1987). Principles of traditional animation applied to 3D computer animation. SIGGRAPH.
  doi:10.1145/37401.37407
- Chang, B.-W., & Ungar, D. (1993). Animation: from cartoons to the user interface. UIST.
  doi:10.1145/168642.168647
- Dragicevic, P., et al. (2011). Temporal distortion for animated transitions. CHI.
  doi:10.1145/1978942.1979233
- Takayama, L., Dooley, D., & Ju, W. (2011). Expressing thought. HRI. doi:10.1145/1957656.1957674
- Ribeiro, T., & Paiva, A. (2012). The illusion of robotic life. HRI. doi:10.1145/2157689.2157814
- Kwon, M., Huang, S. H., & Dragan, A. D. (2018). Expressing robot incapability. HRI.
  doi:10.1145/3171221.3171276
- Laubheimer, P. (2020). Executing UX animations: duration and motion characteristics. NN/g.
  https://www.nngroup.com/articles/animation-duration/

Closure
- Zeigarnik, B. (1927). Das Behalten erledigter und unerledigter Handlungen. *Psychologische Forschung*, 9.
- Ghibellini, R., & Meier, B. (2025). Interruption, recall and resumption: a meta-analysis of the Zeigarnik
  and Ovsiankina effects. *HSSC*. doi:10.1057/s41599-025-05000-w
- Masicampo, E. J., & Baumeister, R. F. (2011). Consider it done! *JPSP*. doi:10.1037/a0024192
- Kivetz, R., Urminsky, O., & Zheng, Y. (2006). The goal-gradient hypothesis resurrected. *JMR*.
  doi:10.1509/jmkr.43.1.39
- Kahneman, D., et al. (1993). When more pain is preferred to less. *Psychological Science*.
  doi:10.1111/j.1467-9280.1993.tb00589.x
- Redelmeier, D. A., & Kahneman, D. (1996). Patients' memories of painful medical treatments. *Pain*.
  doi:10.1016/0304-3959(96)02994-6
- Alaybek, B., et al. (2022). A meta-analysis of the peak-end rule and duration neglect. *OBHDP*.
  doi:10.1016/j.obhdp.2022.104149

Choice and targeting
- Fitts, P. M. (1954). The information capacity of the human motor system. *J. Exp. Psych.*
  doi:10.1037/h0055392
- MacKenzie, I. S. (1992). Fitts' law as a research and design tool in HCI. *HCI*.
  doi:10.1207/s15327051hci0701_3
- Budiu, R. (2022). Fitts's law and its applications in UX. NN/g. https://www.nngroup.com/articles/fitts-law/
- Hick, W. E. (1952). On the rate of gain of information. *QJEP*. doi:10.1080/17470215208416600
- Trick, L. M., & Pylyshyn, Z. W. (1994). Why are small and large numbers enumerated differently?
  *Psychological Review*. doi:10.1037/0033-295X.101.1.80
- Wagemans, J., et al. (2012). A century of Gestalt psychology in visual perception I. *Psychological
  Bulletin*. doi:10.1037/a0029333
- Sekuler, A. B., & Bennett, P. J. (2001). Generalized common fate. *Psychological Science*.
  doi:10.1111/1467-9280.00382
