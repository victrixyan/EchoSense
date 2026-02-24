# EchoSense: Audio Intelligence for Dementia Care

Victrix Yan, Department of Bioengineering, Imperial College London
Email: qingchen.yan24@imperial.ac.uk

# Problem statement

## The Silent Crisis of Dementia Communication

**Dementia** is not merely a loss of memory; it is also a slow-motion erosion of the bridge to the current reality and the ability to communicate. According to the World Health Organization, there are nearly 10 million new cases of dementia worldwide every year, making it one of the leading causes of disability among older people. Patients often "time-travel"—suddenly regressing decades into the past—or experience delusions, hallucinations or volatile mood swings triggered by a world they no longer recognise. Clinically, this reflects damage to brain regions supporting language (leading to word-finding difficulty, reduced understanding, and disorganised speech), as well as impairments in attention, memory, and executive function, so even simple conversations require more cognitive effort than the person can reliably manage. These changes mean the person may misinterpret questions, forget what was just said, or lose the thread of a conversation entirely, which can turn routine interactions into sources of frustration, anxiety, or apparent “uncooperativeness.” Consequently, caregivers commonly struggle to coordinate everyday activities or identify unmet needs.

Dementia costs economies globally around $1.3 trillion per year; approximately 50% of these costs are attributable to care provided by informal carers, such as family members and close friends. As informal carers lack clinical training, they often respond to patient confusion with "reality orientation" (e.g., "It happened a long time ago"), which can inadvertently worsen the situation. The loss is twofold: patients struggle to express their needs and emotions, while caregivers grapple with interpreting confusing, sometimes distressing verbal and nonverbal signals. Over time, the constant effort to “decode” incomplete or confusing speech, manage behavioural changes, and cope with repeated distress can significantly raise rates of caregiver stress and depression compared with the general population.

## The Goal of EchoSense

Our goal is not to replace human communication but to bridge the communication gap between dementia patients and their loved ones, by providing caregivers realtime data-driven assistance during difficult conversations. **EchoSense** is grounded in **person-centred dementia care (PCDC)**, a widely researched and applied care practice. PCDC emphasises knowing the person, accepting their reality without correction, fostering meaningful engagement, and building authentic relationships in a supportive environment, which meta-analyses show reduces agitation, improves well-being, more effectively than task-focused or reality-oriented approaches. Instead of contradicting a confused statement (“No, your mother isn’t coming”), a PCDC response attends to the underlying feeling (“You’re thinking about your mother; tell me about her”). This shift from correction to understanding reduces distress, and helps everyday conversations feel safer and more collaborative for both the person with dementia and their caregiver.

EchoSense applies PCDC with **acoustic intelligence**. Its edge AI model analyses speech to infer cognitive or emotional states in real time. It then provides subtle, context-aware prompts that guide caregivers toward appropriate responses. Running locally on devices such as the carer’s phone ensures privacy and accessibility, even in settings with limited connectivity.

The potential impact of EchoSense lies in making everyday dementia communication less frustrating and more supportive. Improved conversations can reduce caregiver burnout, lower instances of patient distress, and help families sustain home care longer. On a larger scale, even modest gains in daily communication quality could incrementally ease the global care burden by improving well-being rather than merely extending monitoring. EchoSense does not aim to automate empathy but to amplify it—translating the technology into a tool that listens, understands, and guides.

## Overall Solution  

EchoSense uses **MedGemma-1.5-4b** as a clinical reasoning engine to turn speech acoustics + conversation context into person-centred care (PCDC) nudges. It extracts **nine eGeMAPS biomarkers** from audio, combines them with optional patient context (life story, interests) and recent conversation summary, and outputs structured guidance.

**Why MedGemma**: This task requires medical-domain reasoning that links subtle voice biomarkers (e.g., spectral tilt, articulation variability) to cognitive-emotional states and to evidence-based dementia care responses. MedGemma is pre-trained on medical literature and clinical language, enabling it to interpret health-related signals and generate PCDC-aligned guidance. Generic LLMs or sentiment models lack this grounding and tend to produce surface-level empathy or reality-orientation responses that can worsen distress. Rule-based systems cannot adapt to novel patient histories or evolving conversation context. MedGemma provides the best fit for safe, clinically grounded reasoning on-device.

The iOS app is designed to help real conversations: caregivers can add optional patient context, the system detects a current state (agitation score), shows a short trend, extracts key topics, and suggests 1-2 supportive responses aligned with PCDC. A rolling memory updates every 15-20 seconds so guidance adapts across turns rather than reacting to each sentence in isolation. All inference runs on-device via 4-bit quantized CoreML, keeping data private.


## Technical Details

**Tech Stack**: openSMILE 2.3.0 (eGeMAPS) | MedGemma-1.5-4b (4-bit) | Swift + SwiftUI + CoreML | Cohen's d selection (d≥0.10) | JSON rolling memory | AVFoundation (16 kHz) | CoreML Neural Engine (A14+).

- **Data**: 232 audio samples (116 dementia from [DementiaNet](https://github.com/shreyasgite/dementianet), 116 controls), 30–60s each
- **Acoustic features**: openSMILE eGeMAPS v02 → 88 raw parameters
- **Clinical grouping**: 6 domains (phonation, prosody, rhythm, energy, articulation, spectral) → 29 features using means/ranges/ratios (no normalization)
- **Selection**: Cohen's d ≥ 0.10 → 9 features across 4 domains (Energy 4, Spectral 3, Articulation 1, Rhythm 1)
- **Model**: MedGemma-1.5-4b, deterministic decoding, max 120 tokens
- **Prompt** (~200 tokens): profile + session summary + keywords + last nudge + transcripts + biomarkers → VIPS task
- **Output**: Structured JSON (`agitation`, `trend`, `keywords`, `nudges`)
- **Rolling memory**: session state tracks profile, summary, keywords, agitation history, last nudge
- **On-device deployment**: 4-bit quantization, CoreML .mlpackage (prompt_text + biomarkers → json_output)
- **iOS app**: SwiftUI UI + 15–20s loop (audio → features → prompt → inference → JSON → UI)

More detials can be found on [Github - EchoSense](https://github.com/victrixyan/EchoSense.git)

---
*Notice: EchoSense is not designed for medical treatment of dementia.*