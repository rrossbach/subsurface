// SPDX-License-Identifier: GPL-2.0

#include "command_event.h"
#include "core/dive.h"
#include "core/subsurface-qt/divelistnotifier.h"
#include "core/libdivecomputer.h"
#include "core/gettextfromc.h"

namespace Command {

EventBase::EventBase(struct dive *dIn, int dcNrIn) :
	d(dIn), dcNr(dcNrIn)
{
}

void EventBase::redo()
{
	redoit(); // Call actual function in base class
	invalidate_dive_cache(d);
	emit diveListNotifier.eventsChanged(d);
}

void EventBase::undo()
{
	undoit(); // Call actual function in base class
	invalidate_dive_cache(d);
	emit diveListNotifier.eventsChanged(d);
}

AddEventBase::AddEventBase(struct dive *d, int dcNr, struct event *ev) : EventBase(d, dcNr),
	eventToAdd(ev)
{
}

bool AddEventBase::workToBeDone()
{
	return true;
}

void AddEventBase::redoit()
{
	struct divecomputer *dc = get_dive_dc(d, dcNr);
	eventToRemove = eventToAdd.get();
	add_event_to_dc(dc, eventToAdd.release()); // return ownership to backend
}

void AddEventBase::undoit()
{
	struct divecomputer *dc = get_dive_dc(d, dcNr);
	remove_event_from_dc(dc, eventToRemove);
	eventToAdd.reset(eventToRemove); // take ownership of event
	eventToRemove = nullptr;
}

AddEventBookmark::AddEventBookmark(struct dive *d, int dcNr, int seconds) :
	AddEventBase(d, dcNr, create_event(seconds, SAMPLE_EVENT_BOOKMARK, 0, 0, "bookmark"))
{
	setText(tr("Add bookmark"));
}

AddEventDivemodeSwitch::AddEventDivemodeSwitch(struct dive *d, int dcNr, int seconds, int divemode) :
	AddEventBase(d, dcNr, create_event(seconds, SAMPLE_EVENT_BOOKMARK, 0, divemode, QT_TRANSLATE_NOOP("gettextFromC", "modechange")))
{
	setText(tr("Add dive mode switch to %1").arg(gettextFromC::tr(divemode_text_ui[divemode])));
}

AddEventSetpointChange::AddEventSetpointChange(struct dive *d, int dcNr, int seconds, pressure_t pO2) :
	AddEventBase(d, dcNr, create_event(seconds, SAMPLE_EVENT_PO2, 0, pO2.mbar, QT_TRANSLATE_NOOP("gettextFromC", "SP change")))
{
	setText(tr("Add set point change")); // TODO: format pO2 value in bar or psi.
}

RenameEvent::RenameEvent(struct dive *d, int dcNr, struct event *ev, const char *name) : EventBase(d, dcNr),
	eventToAdd(clone_event_rename(ev, name)),
	eventToRemove(ev)
{
	setText(tr("Rename bookmark to %1").arg(name));
}

bool RenameEvent::workToBeDone()
{
	return true;
}

void RenameEvent::redoit()
{
	struct divecomputer *dc = get_dive_dc(d, dcNr);
	swap_event(dc, eventToRemove, eventToAdd.get());
	event *tmp = eventToRemove;
	eventToRemove = eventToAdd.release();
	eventToAdd.reset(tmp);
}

void RenameEvent::undoit()
{
	// Undo and redo do the same thing - they simply swap events
	redoit();
}

RemoveEvent::RemoveEvent(struct dive *d, int dcNr, struct event *ev) : EventBase(d, dcNr),
	eventToRemove(ev)
{
	setText(tr("Remove %1 event").arg(ev->name));
}

bool RemoveEvent::workToBeDone()
{
	return true;
}

void RemoveEvent::redoit()
{
	struct divecomputer *dc = get_dive_dc(d, dcNr);
	remove_event_from_dc(dc, eventToRemove);
	eventToAdd.reset(eventToRemove); // take ownership of event
	eventToRemove = nullptr;
}

void RemoveEvent::undoit()
{
	struct divecomputer *dc = get_dive_dc(d, dcNr);
	eventToRemove = eventToAdd.get();
	add_event_to_dc(dc, eventToAdd.release()); // return ownership to backend
}

} // namespace Command
