// SPDX-License-Identifier: GPL-2.0
#ifndef DIVECARTESIANAXIS_H
#define DIVECARTESIANAXIS_H

#include <QObject>
#include <QGraphicsLineItem>
#include <QPen>
#include "core/color.h"
#include "core/units.h"

class ProfileScene;
class QPropertyAnimation;
class DiveTextItem;
class DiveLineItem;
class DivePlotDataModel;

class DiveCartesianAxis : public QObject, public QGraphicsLineItem {
	Q_OBJECT
	Q_PROPERTY(QLineF line WRITE setLine READ line)
	Q_PROPERTY(QPointF pos WRITE setPos READ pos)
	Q_PROPERTY(qreal x WRITE setX READ x)
	Q_PROPERTY(qreal y WRITE setY READ y)
private:
	bool printMode;
public:
	enum Orientation {
		TopToBottom,
		BottomToTop,
		LeftToRight,
		RightToLeft
	};
	enum class Position {
		Left, Right, Bottom
	};
	DiveCartesianAxis(Position position, color_index_t gridColor, double dpr,
			  bool printMode, bool isGrayscale, ProfileScene &scene);
	~DiveCartesianAxis();
	void setMinimum(double minimum);
	void setMaximum(double maximum);
	void setTickInterval(double interval);
	void setOrientation(Orientation orientation);
	void setFontLabelScale(qreal scale);
	double minimum() const;
	double maximum() const;
	std::pair<double, double> screenMinMax() const;
	qreal valueAt(const QPointF &p) const;
	qreal posAtValue(qreal value) const;
	void animateChangeLine(const QRectF &rect, int animSpeed);
	void setTextVisible(bool arg1);
	void setLinesVisible(bool arg1);
	void setLine(const QLineF &line);
	virtual void updateTicks(int animSpeed);
	double width() const; // only for vertical axes
	double height() const; // only for horizontal axes

signals:
	void sizeChanged();

protected:
	Position position;
	QRectF rect; // Rectangle to fill with grid lines
	QPen gridPen;
	color_index_t gridColor;
	ProfileScene &scene;
	virtual QString textForValue(double value) const;
	virtual QColor colorForValue(double value) const;
	double textWidth(const QString &s) const;
	Orientation orientation;
	QList<DiveTextItem *> labels;
	QList<DiveLineItem *> lines;
	double min;
	double max;
	double interval;
	bool textVisibility;
	bool lineVisibility;
	double labelScale;
	bool changed;
	double dpr;
};

class DepthAxis : public DiveCartesianAxis {
	Q_OBJECT
public:
	DepthAxis(Position position, color_index_t gridColor, double dpr,
		  bool printMode, bool isGrayscale, ProfileScene &scene);
private:
	QString textForValue(double value) const override;
	QColor colorForValue(double value) const override;
};

class TimeAxis : public DiveCartesianAxis {
	Q_OBJECT
public:
	using DiveCartesianAxis::DiveCartesianAxis;
	void updateTicks(int animSpeed) override;
private:
	QString textForValue(double value) const override;
	QColor colorForValue(double value) const override;
};

class TemperatureAxis : public DiveCartesianAxis {
	Q_OBJECT
public:
	using DiveCartesianAxis::DiveCartesianAxis;
private:
	QString textForValue(double value) const override;
};

class PartialGasPressureAxis : public DiveCartesianAxis {
	Q_OBJECT
public:
	PartialGasPressureAxis(const DivePlotDataModel &model, Position position, color_index_t gridColor,
			       double dpr, bool printMode, bool isGrayscale, ProfileScene &scene);
	void update(int animSpeed);
	double width() const;
private:
	const DivePlotDataModel &model;
};

#endif // DIVECARTESIANAXIS_H
