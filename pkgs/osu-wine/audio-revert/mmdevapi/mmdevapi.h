/*
 * Copyright 2009 Maarten Lankhorst
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301, USA
 */

#include "unixlib.h"
#include <wine/unixlib.h>
#include <wine/list.h>

extern HRESULT MMDevEnum_Create(REFIID riid, void **ppv);
extern void MMDevEnum_Free(void);

typedef struct _DriverFuncs {
    HMODULE module;
    WCHAR module_name[64];
    int priority;

    /* Returns a "priority" value for the driver. Highest priority wins.
     * If multiple drivers think they are valid, they will return a
     * priority value reflecting the likelihood that they are actually
     * valid. See enum _DriverPriority. */
    int (WINAPI *pGetPriority)(void);

    /* ids gets an array of human-friendly endpoint names
     * keys gets an array of driver-specific stuff that is used
     *   in GetAudioEndpoint to identify the endpoint
     * it is the caller's responsibility to free both arrays, and
     *   all of the elements in both arrays with HeapFree() */
    HRESULT (WINAPI *pGetEndpointIDs)(EDataFlow flow, WCHAR ***ids,
            GUID **guids, UINT *num, UINT *default_index);
    HRESULT (WINAPI *pGetAudioEndpoint)(void *key, IMMDevice *dev,
            IAudioClient **out);
    HRESULT (WINAPI *pGetAudioSessionManager)(IMMDevice *device,
            IAudioSessionManager2 **out);
    HRESULT (WINAPI *pGetPropValue)(GUID *guid,
            const PROPERTYKEY *prop, PROPVARIANT *out);
} DriverFuncs;

extern DriverFuncs drvs;

typedef struct MMDevice {
    IMMDevice IMMDevice_iface;
    IMMEndpoint IMMEndpoint_iface;
    LONG ref;

    CRITICAL_SECTION crst;

    EDataFlow flow;
    DWORD state;
    GUID devguid;
    WCHAR *drv_id;

    struct list entry;
} MMDevice;

extern HRESULT AudioClient_Create(MMDevice *parent, IAudioClient **ppv);
extern HRESULT AudioEndpointVolume_Create(MMDevice *parent, IAudioEndpointVolumeEx **ppv);
extern HRESULT SpatialAudioClient_Create(IMMDevice *device, ISpatialAudioClient **out);

extern HRESULT load_devices_from_reg(void);
extern HRESULT load_driver_devices(EDataFlow flow);

extern const WCHAR drv_keyW[];
