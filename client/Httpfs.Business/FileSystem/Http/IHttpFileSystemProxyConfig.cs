using System;

using Flurl;

namespace httpfsc.Business.FileSystem.Http
{
    public interface IHttpFileSystemProxyConfig
    {
        #region Properties

        Url ServerRootPath { get; }

        #endregion
    }
}