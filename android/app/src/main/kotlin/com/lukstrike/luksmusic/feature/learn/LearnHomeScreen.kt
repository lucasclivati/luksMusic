// LearnHomeScreen.kt — port of luksMusic/Views/Learn/LearnHomeView.swift.
//
// The "Aprender" tab: the course's modules and their lessons, with the best result of each. A lesson opens when
// the one before it was finished (or all of them, from the menu). The reading drill is reached from here too.
package com.lukstrike.luksmusic.feature.learn

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Piano
import androidx.compose.material.icons.filled.SmartDisplay
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material3.Checkbox
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberTopAppBarState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.lukstrike.luksmusic.R
import com.lukstrike.luksmusic.appContainer
import com.lukstrike.luksmusic.core.lessons.Lesson
import com.lukstrike.luksmusic.core.lessons.LessonCatalog
import com.lukstrike.luksmusic.core.lessons.LessonProgress
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LearnHomeScreen(onOpenLesson: (String) -> Unit, onOpenReadingDrill: () -> Unit) {
    val container = appContainer()
    val store = remember(container) { LessonProgressStore(container.settings) }
    val progress by store.progress.collectAsStateWithLifecycle(initialValue = LessonProgress())
    val scope = rememberCoroutineScope()
    val lessons = LessonCatalog.allLessons
    val scrollBehavior = TopAppBarDefaults.pinnedScrollBehavior(rememberTopAppBarState())
    var menuOpen by remember { mutableStateOf(false) }

    Scaffold(
        modifier = Modifier.nestedScroll(scrollBehavior.nestedScrollConnection),
        containerColor = LearnColors.background,
        // The tab bar below already takes the bottom inset
        contentWindowInsets = androidx.compose.foundation.layout.WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.tab_learn), fontWeight = FontWeight.Bold) },
                scrollBehavior = scrollBehavior,
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = LearnColors.background,
                    scrolledContainerColor = LearnColors.panel,
                    titleContentColor = LearnColors.text,
                ),
                actions = {
                    Box {
                        IconButton(onClick = { menuOpen = true }) {
                            Icon(Icons.Filled.MoreVert, contentDescription = stringResource(R.string.learn_options), tint = LearnColors.text)
                        }
                        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
                            DropdownMenuItem(
                                text = { Text(stringResource(R.string.learn_unlock_all)) },
                                trailingIcon = { Checkbox(checked = progress.unlocksEverything, onCheckedChange = null) },
                                onClick = {
                                    scope.launch { store.setUnlocksEverything(!progress.unlocksEverything) }
                                    menuOpen = false
                                },
                            )
                        }
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = padding.calculateTopPadding() + 4.dp, bottom = 24.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            item {
                Text(stringResource(R.string.learn_intro), color = LearnColors.muted, fontSize = 15.sp)
            }
            item {
                Row(
                    Modifier.fillMaxWidth().background(LearnColors.raised, RoundedCornerShape(10.dp)).padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Icon(Icons.Filled.Piano, contentDescription = null, tint = LearnColors.cyan, modifier = Modifier.size(20.dp))
                    Text(stringResource(R.string.learn_input_tip), color = LearnColors.text, fontSize = 13.sp)
                }
            }
            item {
                DrillCard(onOpenReadingDrill)
            }
            for (module in LessonCatalog.modules) {
                item(key = "module-${module.id}") {
                    Column(Modifier.padding(top = 14.dp, bottom = 2.dp)) {
                        Text(lessonText(module.title), color = LearnColors.text, fontSize = 20.sp, fontWeight = FontWeight.Bold)
                        Text(lessonText(module.summary), color = LearnColors.muted, fontSize = 13.sp)
                    }
                }
                items(module.lessons, key = { it.id }) { lesson ->
                    val number = module.lessons.indexOf(lesson) + 1
                    LessonRow(lesson, number, progress.isOpen(lesson, lessons), progress.stars[lesson.id] ?: 0) {
                        onOpenLesson(lesson.id)
                    }
                }
            }
        }
    }
}

@Composable
private fun DrillCard(onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(LearnColors.panel, RoundedCornerShape(12.dp))
            .border(1.dp, LearnColors.raised, RoundedCornerShape(12.dp))
            .clickable(onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(Modifier.size(36.dp).background(LearnColors.green, CircleShape), contentAlignment = Alignment.Center) {
            Icon(Icons.Filled.Visibility, contentDescription = null, tint = LearnColors.background, modifier = Modifier.size(20.dp))
        }
        Column(Modifier.weight(1f)) {
            Text(stringResource(R.string.learn_drill_title), color = LearnColors.text, fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            Text(stringResource(R.string.learn_drill_card_summary), color = LearnColors.muted, fontSize = 12.sp)
        }
        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = LearnColors.muted)
    }
}

/** Marks a lesson that opens with an animated introduction. */
@Composable
private fun VideoBadge() {
    Row(
        Modifier.background(LearnColors.cyan.copy(alpha = 0.16f), CircleShape).padding(horizontal = 6.dp, vertical = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Icon(Icons.Filled.SmartDisplay, contentDescription = null, tint = LearnColors.cyan, modifier = Modifier.size(11.dp))
        Text(stringResource(R.string.learn_video), color = LearnColors.cyan, fontSize = 10.sp, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun LessonRow(lesson: Lesson, number: Int, isOpen: Boolean, earned: Int, onClick: () -> Unit) {
    Row(
        Modifier
            .fillMaxWidth()
            .background(LearnColors.panel, RoundedCornerShape(12.dp))
            .border(1.dp, LearnColors.raised, RoundedCornerShape(12.dp))
            .clickable(enabled = isOpen, onClick = onClick)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            Modifier.size(36.dp).background(if (isOpen) LearnColors.cyan else LearnColors.border, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Text("$number", color = LearnColors.background, fontSize = 16.sp, fontWeight = FontWeight.Bold)
        }
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(lessonText(lesson.title), color = if (isOpen) LearnColors.text else LearnColors.muted, fontSize = 16.sp,
                    fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f, fill = false))
                if (lesson.hasIntro) VideoBadge()
            }
            Text(lessonText(lesson.summary), color = LearnColors.muted, fontSize = 12.sp)
        }
        Spacer(Modifier.width(8.dp))
        when {
            earned > 0 -> {
                val label = pluralStringResource(R.plurals.learn_stars_of_three, earned, earned)
                StarRow(earned, 13.dp, Modifier.clearAndSetSemantics { contentDescription = label }, animated = false)
            }
            !isOpen -> Icon(Icons.Filled.Lock, contentDescription = stringResource(R.string.learn_locked), tint = LearnColors.muted, modifier = Modifier.size(16.dp))
            else -> Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, contentDescription = null, tint = LearnColors.muted)
        }
    }
}
